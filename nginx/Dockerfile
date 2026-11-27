FROM nginx:1.27-alpine

# OpenSSL is used to create the local development certificate.
RUN apk add --no-cache openssl

COPY docker-entrypoint.d/10-generate-dev-cert.sh /docker-entrypoint.d/10-generate-dev-cert.sh
RUN chmod 755 /docker-entrypoint.d/10-generate-dev-cert.sh
