# define the liboqs tag to be used
ARG LIBOQS_TAG=main

# define the oqsprovider tag to be used
ARG OQSPROVIDER_TAG=main

# liboqs build type variant; maximum portability of image:
ARG LIBOQS_BUILD_DEFINES="-DOQS_DIST_BUILD=ON"
ARG WOLFSSL_VERSION=development
ARG NGINX_VERSION=1.24.0
ARG MAKE_DEFINES="-j 18"

FROM alpine:3.14 AS builder

RUN set -eux \
  # install deps
  && apk add --no-cache --virtual .build-deps \
  bash \
  autoconf \
  automake \
  file \
  cmake \
  ninja \
  git \
  g++ \
  libtool \
  make \
  patch \
  zlib-dev \
  pcre-dev \
  linux-headers \
  openssl-dev \
  openssl-libs-static \
  openssl \
  util-linux-dev

###############################################################################
FROM builder AS fetcher

ARG LIBOQS_TAG
ARG OQSPROVIDER_TAG
ARG LIBOQS_BUILD_DEFINES
ARG WOLFSSL_VERSION
ARG NGINX_VERSION

# get OQS sources
WORKDIR /opt

RUN git clone --depth 1 --branch ${LIBOQS_TAG} https://github.com/open-quantum-safe/liboqs

# get wolfssl sources
RUN git clone --depth 1 --branch ${WOLFSSL_VERSION} https://github.com/Laboratory-for-Safe-and-Secure-Systems/wolfssl.git wolfssl-${WOLFSSL_VERSION}

# get nginx sources
RUN wget nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && tar -zxvf nginx-${NGINX_VERSION}.tar.gz;

WORKDIR /opt/nginx-${NGINX_VERSION}

RUN wget https://raw.githubusercontent.com/wolfSSL/wolfssl-nginx/master/nginx-1.24.0-wolfssl.patch
COPY ./nginx-1.24.0-pq.patch /opt/nginx-${NGINX_VERSION}/patch.patch
RUN patch -p1 < patch.patch
RUN patch -p1 < nginx-1.24.0-wolfssl.patch


###############################################################################
FROM builder AS oqs

ARG LIBOQS_BUILD_DEFINES

# get OQS sources
COPY --from=fetcher /opt/liboqs /opt/liboqs

# build liboqs (static only)
WORKDIR /opt/liboqs

RUN mkdir build && cd build && cmake -G"Ninja" -DCMAKE_INSTALL_PREFIX=/usr/local -DOQS_USE_OPENSSL=OFF .. && ninja && ninja install

###############################################################################
FROM builder AS wolfssl-nginx

RUN ln -sf /bin/bash /bin/sh

ENV SHELL=/bin/bash

ARG WOLFSSL_VERSION
ARG NGINX_VERSION
ARG MAKE_DEFINES

# copy liboqs from previous stage
COPY --from=oqs /usr/local /usr/local

COPY --from=fetcher /opt/wolfssl-${WOLFSSL_VERSION} /opt/wolfssl-${WOLFSSL_VERSION}
COPY --from=fetcher /opt/nginx-${NGINX_VERSION} /opt/nginx-${NGINX_VERSION}

WORKDIR /opt

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

###############################################################################
FROM builder AS curl-with-wolfssl

RUN apk add --no-cache libpsl-dev

WORKDIR /opt

RUN wget https://github.com/curl/curl/releases/download/curl-8_6_0/curl-8.6.0.zip

RUN unzip curl-8.6.0.zip

WORKDIR /opt/curl-8.6.0

RUN ./configure --with-wolfssl

RUN make ${MAKE_DEFINES} && make install

###############################################################################
FROM alpine AS nginx

RUN apk add --no-cache bash pcre zlib openssl

ENV PATH=$PATH:/usr/local/nginx/sbin

RUN mkdir -p /var/log/nginx /var/cache/nginx

COPY ./nginx.conf /tmp/nginx.conf

RUN addgroup -S nginx && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

EXPOSE 80 443

STOPSIGNAL SIGTERM

COPY ./entrypoint-nginx.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["nginx", "-g", "daemon off; error_log /dev/stderr info;"]

