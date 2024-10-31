#!/bin/sh

set -eux

# Wait for /usr/local/ to be populated by the first mount
timeout=60
while [ $timeout -gt 0 ]; do
  if [ -d "/usr/local/lib" ]; then
    echo "/usr/local/ is ready."
    break
  fi
  echo "Waiting for /usr/local/ to be mounted..."
  sleep 1
  timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
  echo "Timeout waiting for /usr/local/ to be ready."
  exit 1
fi

# Copy or link certificates after /usr/local/ is ready
cp /tmp/nginx.conf /usr/local/nginx/conf/nginx.conf
cp /tmp/server_cert.pem /usr/local/nginx/conf/server_cert.pem
cp /tmp/server_key.pem /usr/local/nginx/conf/server_key.pem

# Start NGINX
exec "$@"

