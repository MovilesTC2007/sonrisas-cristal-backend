\getenv api_db_user API_DB_USER
\getenv api_db_password API_DB_PASSWORD
\getenv postgres_db POSTGRES_DB

-- Keep the API login separate from the database administrator.
SELECT format(
    'DO $role_guard$ BEGIN IF %L = current_user THEN RAISE EXCEPTION ''API_DB_USER must differ from POSTGRES_USER''; END IF; END $role_guard$',
    :'api_db_user'
)
\gexec

SELECT format(
    'CREATE ROLE %I WITH LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS',
    :'api_db_user',
    :'api_db_password'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = :'api_db_user'
)
\gexec

SELECT format(
    'ALTER ROLE %I WITH LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS',
    :'api_db_user',
    :'api_db_password'
)
\gexec

GRANT CONNECT ON DATABASE :"postgres_db" TO :"api_db_user";
GRANT USAGE ON SCHEMA public TO :"api_db_user";
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"api_db_user";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO :"api_db_user";
GRANT USAGE ON TYPE types_of_requests, status_of_requests, status_of_attendance TO :"api_db_user";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO :"api_db_user";
REVOKE EXECUTE ON FUNCTION get_password_pepper() FROM PUBLIC;
SELECT format(
    'REVOKE EXECUTE ON FUNCTION get_password_pepper() FROM %I',
    :'api_db_user'
)
\gexec

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"api_db_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO :"api_db_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE ON TYPES TO :"api_db_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO :"api_db_user";
