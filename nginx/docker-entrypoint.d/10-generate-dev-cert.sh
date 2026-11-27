#!/bin/sh
set -eu

CERT_DIR=/etc/nginx/certs
CERT_FILE="$CERT_DIR/local_cert.pem"
KEY_FILE="$CERT_DIR/local_key.pem"

if [ -s "$CERT_FILE" ] && [ -s "$KEY_FILE" ]; then
  exit 0
fi

# Generate a self-signed certificate only when the development Compose file opts in.
if [ "${GENERATE_DEV_CERT:-false}" != "true" ]; then
  echo "TLS certificate files are missing; provide local_cert.pem and local_key.pem." >&2
  exit 1
fi

umask 077
mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
