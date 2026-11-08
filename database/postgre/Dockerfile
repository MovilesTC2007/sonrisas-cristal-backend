FROM postgres:16-alpine

# https://docs.docker.com/guides/pre-seeding/
# Files in /docker-entrypoint-initdb.d/ run once, in alphabetical order, only
# when the data directory is empty (first container start). The numeric
# prefixes guarantee tables.sql runs before seed.sql regardless of the
# original filenames.

COPY tables.sql /docker-entrypoint-initdb.d/01-tables.sql
COPY seed.sql /docker-entrypoint-initdb.d/02-seed.sql
