#!/bin/bash

set -eux

# Define paths
WOLFSSL_DIR="/opt/wolfssl-${WOLFSSL_VERSION}"
NGINX_MARKER="/opt/nginx-${WOLFSSL_VERSION}.built"

# Function to build wolfSSL
build_wolfssl() {
  echo "Building wolfSSL..."
  cd "$WOLFSSL_DIR"
  ./autogen.sh
  ./configure --prefix=/usr/local \
    --enable-all \
    --enable-tls13 \
    --enable-tlsx \
    --enable-session-ticket \
    --enable-nullcipher \
    --enable-harden \
    --enable-asn=template \
    --enable-opensslextra \
    --enable-experimental \
    --enable-kyber=yes \
    --enable-dual-alg-certs \
    --enable-dilithium=yes,fips204-draft \
    --disable-examples \
    --enable-nginx \
    --enable-keylog-export \
    --enable-debug
  make -j"$(nproc)"
  make -j"$(nproc)" check
  make install -j"$(nproc)"
  echo "$latest_commit" > "$WOLFSSL_DIR/.last_built_commit"
}

# Check if there’s a new commit in wolfSSL
cd "$WOLFSSL_DIR"
git fetch origin "$WOLFSSL_VERSION"
latest_commit=$(git rev-parse origin/"$WOLFSSL_VERSION")
last_built_commit=$(cat "$WOLFSSL_DIR/.last_built_commit" 2>/dev/null || echo "")

if [ "$latest_commit" != "$last_built_commit" ]; then
  build_wolfssl
else
  echo "wolfSSL is already up-to-date."
fi

# Function to build NGINX
build_nginx() {
  echo "Building NGINX..."
  cd /opt/nginx-"$NGINX_VERSION"
  ./configure \
    --with-debug \
    --with-wolfssl=/usr/local \
    --with-http_ssl_module
  make -j"$(nproc)"
  make install -j"$(nproc)"
  touch "$NGINX_MARKER"
}

# Check if NGINX needs building
if [ ! -f "$NGINX_MARKER" ]; then
  build_nginx
else
  echo "NGINX is already built and up-to-date."
fi

# Start NGINX
exec "$@"
