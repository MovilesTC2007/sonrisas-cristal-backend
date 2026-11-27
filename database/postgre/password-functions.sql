-- Read the pepper from its mounted secret instead of a PostgreSQL setting.
CREATE OR REPLACE FUNCTION get_password_pepper()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
    SELECT rtrim(pg_read_file('/run/secrets/password_pepper'), E'\r\n');
$$;

REVOKE ALL ON FUNCTION get_password_pepper() FROM PUBLIC;

-- Redeem an invitation and create its user.
CREATE OR REPLACE FUNCTION redeem_invitation_code(p_code TEXT, p_email TEXT, p_password TEXT)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    WITH invitation AS (
        DELETE FROM invitation_code ic
        WHERE ic.code = upper(p_code) AND ic.expires_at > now()
        RETURNING ic.daycare_id, ic.role_id, ic.position_id, ic.name, ic.lastname, ic.is_active
    )
    INSERT INTO users (daycare_id, name, lastname, password_hash, email, role_id, position_id, is_active)
    SELECT
        invitation.daycare_id, invitation.name, invitation.lastname,
        crypt(encode(hmac(p_password, get_password_pepper(), 'sha256'), 'base64'), gen_salt('bf', 12)),
        p_email, invitation.role_id, invitation.position_id, invitation.is_active
    FROM invitation
    RETURNING user_id;
$$;

-- Authenticate an active user by email and password.
CREATE OR REPLACE FUNCTION authenticate(p_email TEXT, p_password TEXT)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    SELECT u.user_id
    FROM users u
    WHERE u.email = p_email
      AND u.is_active = TRUE
      AND u.password_hash = crypt(
          encode(hmac(p_password, get_password_pepper(), 'sha256'), 'base64'),
          u.password_hash
      );
$$;

-- Create a user and hash the password with the mounted pepper.
CREATE OR REPLACE FUNCTION add_user(
    p_daycare_id UUID, p_name TEXT, p_lastname TEXT, p_password TEXT,
    p_email TEXT, p_role_id UUID, p_position_id UUID, p_is_active BOOLEAN
)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    INSERT INTO users (daycare_id, name, lastname, password_hash, email, role_id, position_id, is_active)
    VALUES (
        p_daycare_id, p_name, p_lastname,
        crypt(encode(hmac(p_password, get_password_pepper(), 'sha256'), 'base64'), gen_salt('bf', 12)),
        p_email, p_role_id, p_position_id, p_is_active
    )
    RETURNING user_id;
$$;
