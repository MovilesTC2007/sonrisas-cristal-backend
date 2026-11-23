#!/bin/sh
# Creates the first director account from env vars. Only runs on initial DB
# setup (see Dockerfile), so no existence check is needed. No-op if unset.
set -e

[ -z "$BOOTSTRAP_ADMIN_EMAIL" ] && exit 0

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -v email="$BOOTSTRAP_ADMIN_EMAIL" \
    -v password="$BOOTSTRAP_ADMIN_PASSWORD" \
    -v name="$BOOTSTRAP_ADMIN_NAME" \
    -v lastname="$BOOTSTRAP_ADMIN_LASTNAME" <<-'EOSQL'
    SELECT add_user(
        (SELECT daycare_id FROM daycare ORDER BY daycare_id LIMIT 1),
        :'name', :'lastname', :'password', :'email',
        (SELECT role_id FROM roles WHERE description = 'director'),
        NULL, TRUE
    );
EOSQL
