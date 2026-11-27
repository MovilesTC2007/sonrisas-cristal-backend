FROM postgres:16-alpine

# https://docs.docker.com/guides/pre-seeding/
# Files in /docker-entrypoint-initdb.d/ run once, in alphabetical order, only
# when the data directory is empty (first container start). The numeric
# prefixes guarantee tables.sql runs before seed.sql regardless of the
# original filenames.

COPY tables.sql /docker-entrypoint-initdb.d/01-tables.sql
COPY functions.sql /docker-entrypoint-initdb.d/02-functions.sql
COPY password-functions.sql /docker-entrypoint-initdb.d/02-password-functions.sql
COPY seed.sql /docker-entrypoint-initdb.d/03-seed.sql
# Create the API login after the schema and seed data exist.
COPY 04-api-role.sql /docker-entrypoint-initdb.d/04-api-role.sql