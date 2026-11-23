-- POSTGRESQL
-- This are the Functions and Procedures divided by tables
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ROLES

-- obtain the role name by its ID
CREATE OR REPLACE FUNCTION get_roles_description(p_role_id UUID)
RETURNS TEXT
LANGUAGE sql AS $$
    SELECT description FROM roles WHERE role_id = p_role_id;
$$;


-- POSITIONS

-- obtain the position name by its ID
CREATE OR REPLACE FUNCTION get_position_description(p_position_id UUID)
RETURNS TEXT
LANGUAGE sql AS $$
    SELECT description FROM positions WHERE position_id = p_position_id;
$$;


-- DAYCARE

-- get daycare data by its ID, including its 5 other attributes (name, address, low delay, medium delay, absence)
CREATE OR REPLACE FUNCTION get_daycare_by_id(p_daycare_id UUID)
RETURNS TABLE (name TEXT, address TEXT, low_delay INT, medium_delay INT, absence INT)
LANGUAGE sql AS $$
    SELECT d.name, d.address, d.low_delay, d.medium_delay, d.absence FROM daycare d WHERE d.daycare_id = p_daycare_id;
$$;

-- create a daycare with its 5 attributes
CREATE OR REPLACE FUNCTION add_daycare(p_name TEXT, p_address TEXT, p_low_delay INT, p_medium_delay INT, p_absence INT)
RETURNS UUID
LANGUAGE sql AS $$
    INSERT INTO daycare (name, address, low_delay, medium_delay, absence) VALUES (p_name, p_address, p_low_delay, p_medium_delay, p_absence)
    RETURNING daycare_id;
$$;

-- modify a daycare obtaining its 5 attributes and changing them
CREATE OR REPLACE FUNCTION modify_daycare(p_daycare_id UUID, p_name TEXT, p_address TEXT, p_low_delay INT, p_medium_delay INT, p_absence INT)
RETURNS UUID
LANGUAGE sql AS $$
    UPDATE daycare SET name = p_name, address = p_address, low_delay = p_low_delay, medium_delay = p_medium_delay, absence = p_absence WHERE daycare_id = p_daycare_id
    RETURNING daycare_id;
$$;

-- get the IDs of the active users of a daycare by its ID
CREATE OR REPLACE FUNCTION get_active_personnel(p_daycare_id UUID)
RETURNS TABLE (user_id UUID)
LANGUAGE sql AS $$
    SELECT u.user_id FROM users u WHERE u.daycare_id = p_daycare_id AND u.is_active = TRUE;
$$;


-- AREA

-- get an area info by its ID, including its 3 attributes (daycare id, name and minimum active staff)
CREATE OR REPLACE FUNCTION get_area_by_id(p_area_id UUID)
RETURNS TABLE (daycare_id UUID, name TEXT, minimum_active_staff INT)
LANGUAGE sql AS $$
    SELECT a.daycare_id, a.name, a.minimum_active_staff FROM area a WHERE a.area_id = p_area_id;
$$;

-- get the areas of a daycare by its ID, inclusing its ID, name and minimum active staff
CREATE OR REPLACE FUNCTION get_daycare_areas(p_daycare_id UUID)
RETURNS TABLE (area_id UUID, name TEXT, minimum_active_staff INT)
LANGUAGE sql AS $$
    SELECT a.area_id, a.name, a.minimum_active_staff FROM area a WHERE a.daycare_id = p_daycare_id;
$$;

-- get the IDs of the users in a specific area
CREATE OR REPLACE FUNCTION get_area_personnel(p_area_id UUID)
RETURNS TABLE (user_id UUID)
LANGUAGE sql AS $$
    SELECT DISTINCT s.user_id FROM shift s WHERE s.area_id = p_area_id;
$$;

-- create an area using the 3 arguments and getting back its new ID
CREATE OR REPLACE FUNCTION add_area(p_daycare_id UUID, p_name TEXT, p_minimum_active_staff INT)
RETURNS UUID
LANGUAGE sql AS $$
    INSERT INTO area (daycare_id, name, minimum_active_staff) VALUES (p_daycare_id, p_name, p_minimum_active_staff)
    RETURNING area_id;
$$;

-- modify an area replacing its attributes
CREATE OR REPLACE FUNCTION modify_area(p_area_id UUID, p_name TEXT, p_minimum_active_staff INT)
RETURNS UUID
LANGUAGE sql AS $$
    UPDATE area SET name = p_name, minimum_active_staff = p_minimum_active_staff WHERE area_id = p_area_id
    RETURNING area_id;
$$;


-- INVITATION CODE

-- create a new invitation code for a predefined name/lastname/role/position/is_active, generates a random 6 length code and returns it
CREATE OR REPLACE FUNCTION generate_invitation_code(
    p_daycare_id UUID, p_role_id UUID, p_position_id UUID,
    p_name TEXT, p_lastname TEXT, p_is_active BOOLEAN, p_expires_at TIMESTAMP
)
RETURNS TEXT
LANGUAGE plpgsql AS $$
DECLARE
    v_alphabet CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
    v_code TEXT;
BEGIN
    FOR i IN 1..5 LOOP
        v_code := '';
        FOR j IN 1..6 LOOP
            v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::INT, 1);
        END LOOP;

        INSERT INTO invitation_code (daycare_id, role_id, position_id, name, lastname, is_active, expires_at, code)
        VALUES (p_daycare_id, p_role_id, p_position_id, p_name, p_lastname, p_is_active, p_expires_at, v_code)
        ON CONFLICT (code) DO NOTHING;

        IF FOUND THEN
            RETURN v_code;
        END IF;
    END LOOP;

    RAISE EXCEPTION 'Could not generate a unique code';
END;
$$;

-- redeem an invitation code: consumes it and creates the user from the predefined fields stored on
-- the invitation plus the email/password supplied by the person redeeming it. Returns no rows if the
-- code does not exist or has expired, otherwise returns the new user ID.
CREATE OR REPLACE FUNCTION redeem_invitation_code(p_code TEXT, p_email TEXT, p_password TEXT)
RETURNS UUID
LANGUAGE sql AS $$
    WITH invitation AS (
        DELETE FROM invitation_code ic
        WHERE ic.code = upper(p_code) AND ic.expires_at > now()
        RETURNING ic.daycare_id, ic.role_id, ic.position_id, ic.name, ic.lastname, ic.is_active
    )
    INSERT INTO users (daycare_id, name, lastname, password_hash, email, role_id, position_id, is_active)
    SELECT
        invitation.daycare_id, invitation.name, invitation.lastname,
        crypt(encode(hmac(p_password, current_setting('app.password_pepper'), 'sha256'), 'base64'), gen_salt('bf', 12)),
        p_email, invitation.role_id, invitation.position_id, invitation.is_active
    FROM invitation
    RETURNING user_id;
$$;


-- USERS

-- get an user info by its ID, including daycare ID, name, last name, email, role ID, position ID, if its active and the last update date
CREATE OR REPLACE FUNCTION get_user_by_id(p_user_id UUID)
RETURNS TABLE (daycare_id UUID, name TEXT, lastname TEXT, email TEXT, role_id UUID, position_id UUID, is_active BOOLEAN, updated_at TIMESTAMPTZ)
LANGUAGE sql AS $$
    SELECT u.daycare_id, u.name, u.lastname, u.email, u.role_id, u.position_id, u.is_active, u.updated_at FROM users u WHERE u.user_id = p_user_id;
$$;

-- modify an user replacing its attributes
CREATE OR REPLACE FUNCTION modify_user(p_user_id UUID, p_daycare_id UUID, p_name TEXT, p_lastname TEXT, p_email TEXT, p_role_id UUID, p_position_id UUID, p_is_active BOOLEAN)
RETURNS UUID
LANGUAGE sql AS $$
    UPDATE users SET daycare_id = p_daycare_id, name = p_name, lastname = p_lastname, email = p_email, role_id = p_role_id, position_id = p_position_id, is_active = p_is_active WHERE user_id = p_user_id
    RETURNING user_id;
$$;


-- authenticate by email and password, returns user id or NULL
CREATE OR REPLACE FUNCTION authenticate(p_email TEXT, p_password TEXT)
RETURNS UUID
LANGUAGE sql AS $$
    SELECT u.user_id FROM users u WHERE u.email = p_email AND u.is_active = TRUE
    AND u.password_hash = crypt(
        encode(hmac(p_password, current_setting('app.password_pepper'), 'sha256'), 'base64'), u.password_hash);
$$;

-- create a new user and attributes
CREATE OR REPLACE FUNCTION add_user(p_daycare_id UUID, p_name TEXT, p_lastname TEXT, p_password TEXT, p_email TEXT, p_role_id UUID, p_position_id UUID, p_is_active BOOLEAN)
RETURNS UUID
LANGUAGE sql AS $$
    INSERT INTO users (daycare_id, name, lastname, password_hash, email, role_id, position_id, is_active)
    VALUES (p_daycare_id, p_name, p_lastname,
    crypt(encode(hmac(p_password, current_setting('app.password_pepper'), 'sha256'), 'base64'), gen_salt('bf', 12)),
    p_email, p_role_id, p_position_id, p_is_active)
    RETURNING user_id;
$$;


-- REQUESTS

-- get the requests attributes by its id, this includes user id, type, status, date of creation, day of resolution, person who resolved it and notes
CREATE OR REPLACE FUNCTION get_request_by_id(p_request_id UUID)
RETURNS TABLE (user_id UUID, type types_of_requests, status status_of_requests, request_date TIMESTAMPTZ, resolved_at TIMESTAMPTZ, resolved_by UUID, notes TEXT)
LANGUAGE sql AS $$
    SELECT r.user_id, r.type, r.status, r.request_date, r.resolved_at, r.resolved_by, r.notes FROM requests r WHERE r.request_id = p_request_id;
$$;

-- get the requests from an specific user
CREATE OR REPLACE FUNCTION get_user_requests(p_user_id UUID)
RETURNS TABLE (request_id UUID)
LANGUAGE sql AS $$
    SELECT r.request_id FROM requests r WHERE r.user_id = p_user_id;
$$;

-- create a new request and attributes
CREATE OR REPLACE FUNCTION add_request(p_user_id UUID, p_type types_of_requests, p_status status_of_requests, p_request_date TIMESTAMPTZ, p_resolved_at TIMESTAMPTZ, p_resolved_by UUID, p_notes TEXT)
RETURNS UUID
LANGUAGE sql AS $$
    INSERT INTO requests (user_id, type, status, request_date, resolved_at, resolved_by, notes) VALUES (p_user_id, p_type, p_status, p_request_date, p_resolved_at, p_resolved_by, p_notes)
    RETURNING request_id;
$$;

-- SHIFT

-- create a new shift and attributes
CREATE OR REPLACE FUNCTION add_shift(p_user_id UUID, p_area_id UUID, p_entry_hour TIME, p_exit_hour TIME, p_workday SMALLINT, p_valid_from DATE, p_valid_until DATE, p_is_active BOOLEAN, p_request_id UUID)
RETURNS UUID
LANGUAGE sql AS $$
    INSERT INTO shift (user_id, area_id, entry_hour, exit_hour, workday, valid_from, valid_until, is_active, request_id) VALUES (p_user_id, p_area_id, p_entry_hour, p_exit_hour, p_workday, p_valid_from, p_valid_until, p_is_active, p_request_id)
    RETURNING shift_id;
$$;

-- modify a shift register with new attributes
CREATE OR REPLACE FUNCTION modify_shift(p_shift_id UUID, p_user_id UUID, p_area_id UUID, p_entry_hour TIME, p_exit_hour TIME, p_workday SMALLINT, p_valid_from DATE, p_valid_until DATE, p_is_active BOOLEAN, p_request_id UUID)
RETURNS UUID
LANGUAGE sql AS $$
    UPDATE shift SET user_id = p_user_id, area_id = p_area_id, entry_hour = p_entry_hour, exit_hour = p_exit_hour, workday = p_workday, valid_from = p_valid_from, valid_until = p_valid_until, is_active = p_is_active, request_id = p_request_id, updated_at = now() WHERE shift_id = p_shift_id
    RETURNING shift_id;
$$;

-- get a shift data by its id
CREATE OR REPLACE FUNCTION get_shift_data_by_id(p_shift_id UUID)
RETURNS TABLE (user_id UUID, area_id UUID, entry_hour TIME, exit_hour TIME, workday SMALLINT, valid_from DATE, valid_until DATE, is_active BOOLEAN, request_id UUID)
LANGUAGE sql AS $$
    SELECT s.user_id, s.area_id, s.entry_hour, s.exit_hour, s.workday, s.valid_from, s.valid_until, s.is_active, s.request_id FROM shift s WHERE s.shift_id = p_shift_id;
$$;

-- get an users current shift days, returns the ids of their shift
CREATE OR REPLACE FUNCTION get_user_current_shift_days(p_user_id UUID)
RETURNS TABLE (shift_id UUID)
LANGUAGE sql AS $$
    SELECT s.shift_id FROM shift s WHERE s.user_id = p_user_id AND s.is_active AND (s.valid_from IS NULL OR s.valid_from <= CURRENT_DATE) AND (s.valid_until IS NULL OR s.valid_until >= CURRENT_DATE) ORDER BY s.workday;
$$;

-- get users who are in shift in a certain datetime on the daycare
CREATE OR REPLACE FUNCTION get_users_in_shift_by_daycare(p_shift_time TIMESTAMPTZ, p_daycare_id UUID)
RETURNS TABLE (user_id UUID)
LANGUAGE sql AS $$
    SELECT DISTINCT s.user_id FROM shift s JOIN area a ON a.area_id = s.area_id
    WHERE a.daycare_id = p_daycare_id AND s.is_active
      AND s.workday = EXTRACT(DOW FROM p_shift_time)::smallint
      AND p_shift_time::time BETWEEN s.entry_hour AND s.exit_hour
      AND (s.valid_from IS NULL OR s.valid_from <= p_shift_time::date)
      AND (s.valid_until IS NULL OR s.valid_until >= p_shift_time::date);
$$;

-- get users who should be on an specific day on the daycare
CREATE OR REPLACE FUNCTION get_users_in_day_by_daycare(p_daycare_id UUID, p_date DATE)
RETURNS TABLE (user_id UUID)
LANGUAGE sql AS $$
    SELECT DISTINCT s.user_id FROM shift s JOIN area a ON a.area_id = s.area_id
    WHERE a.daycare_id = p_daycare_id AND s.is_active
      AND s.workday = EXTRACT(DOW FROM p_date)::smallint
      AND (s.valid_from IS NULL OR s.valid_from <= p_date)
      AND (s.valid_until IS NULL OR s.valid_until >= p_date);
$$;


-- ATTENDANCE

-- get a specific user attendances, returns the IDs of the attendances
CREATE OR REPLACE FUNCTION get_user_attendances(p_user_id UUID)
RETURNS TABLE (attendance_id UUID)
LANGUAGE sql AS $$
    SELECT a.attendance_id FROM attendance a WHERE a.user_id = p_user_id ORDER BY a.attendance_date DESC;
$$;

-- register an attendance
CREATE OR REPLACE FUNCTION add_attendance(p_user_id UUID, p_shift_id UUID, p_attendance_date DATE, p_check_in TIMESTAMPTZ, p_status status_of_attendance, p_notes TEXT, p_registered_by UUID, p_uuid TEXT)
RETURNS UUID
LANGUAGE sql AS $$
    INSERT INTO attendance (user_id, shift_id, attendance_date, check_in, status, notes, registered_by, uuid) VALUES (p_user_id, p_shift_id, p_attendance_date, p_check_in, p_status, p_notes, p_registered_by, p_uuid)
    RETURNING attendance_id;
$$;

-- modify an attendance registry
CREATE OR REPLACE FUNCTION modify_attendance(p_attendance_id UUID, p_check_in TIMESTAMPTZ, p_check_out TIMESTAMPTZ, p_status status_of_attendance, p_notes TEXT)
RETURNS UUID
LANGUAGE sql AS $$
    UPDATE attendance SET check_in = p_check_in, check_out = p_check_out, status = p_status, notes = p_notes WHERE attendance_id = p_attendance_id
    RETURNING attendance_id;
$$;

-- get attendance in a daycare in the current shift, returns who are in the daycare now
CREATE OR REPLACE FUNCTION get_attendance_in_daycare_by_current_shift(p_daycare_id UUID, p_datetime TIMESTAMPTZ)
RETURNS TABLE (user_id UUID, name TEXT, lastname TEXT)
LANGUAGE sql AS $$
    SELECT DISTINCT u.user_id, u.name, u.lastname FROM attendance a
    JOIN shift s ON s.shift_id = a.shift_id
    JOIN area ar ON ar.area_id = s.area_id
    JOIN users u ON u.user_id = a.user_id
    WHERE ar.daycare_id = p_daycare_id AND a.attendance_date = p_datetime::date AND p_datetime::time BETWEEN s.entry_hour AND s.exit_hour AND a.check_in IS NOT NULL AND a.check_out IS NULL;
$$;

-- get attendance in an specific day on a daycare
CREATE OR REPLACE FUNCTION get_attendance_in_daycare_by_day(p_daycare_id UUID, p_date DATE)
RETURNS TABLE (user_id UUID, name TEXT, lastname TEXT)
LANGUAGE sql AS $$
    SELECT DISTINCT u.user_id, u.name, u.lastname FROM attendance a
    JOIN shift s ON s.shift_id = a.shift_id
    JOIN area ar ON ar.area_id = s.area_id
    JOIN users u ON u.user_id = a.user_id
    WHERE ar.daycare_id = p_daycare_id AND a.attendance_date = p_date AND a.check_in IS NOT NULL;
$$;


-- PERSONNEL HISTORY

-- add a registry of personnel history
CREATE OR REPLACE FUNCTION add_personnel_history(p_user_id UUID, p_action TEXT, p_action_date DATE, p_notes TEXT, p_changed_by UUID)
RETURNS UUID
LANGUAGE sql AS $$
    INSERT INTO personnel_history (user_id, action, action_date, notes, changed_by) VALUES (p_user_id, p_action, p_action_date, p_notes, p_changed_by)
    RETURNING personnel_history_id;
$$;

-- modify an specific registry
CREATE OR REPLACE FUNCTION modify_personnel_history(p_personnel_history_id UUID, p_action TEXT, p_action_date DATE, p_notes TEXT, p_changed_by UUID)
RETURNS UUID
LANGUAGE sql AS $$
    UPDATE personnel_history SET action = p_action, action_date = p_action_date, notes = p_notes, changed_by = p_changed_by WHERE personnel_history_id = p_personnel_history_id
    RETURNING personnel_history_id;
$$;

-- get personnel history data by its id, returns action, action date, notes and the person id who changed it
CREATE OR REPLACE FUNCTION get_personnel_history_by_id(p_personnel_history_id UUID)
RETURNS TABLE (action TEXT, action_date DATE, notes TEXT, changed_by UUID)
LANGUAGE sql AS $$
    SELECT ph.action, ph.action_date, ph.notes, ph.changed_by FROM personnel_history ph WHERE ph.personnel_history_id = p_personnel_history_id;
$$;

-- get an specific user history
CREATE OR REPLACE FUNCTION get_user_history(p_user_id UUID)
RETURNS TABLE (personnel_history_id UUID)
LANGUAGE sql AS $$
    SELECT ph.personnel_history_id FROM personnel_history ph WHERE ph.user_id = p_user_id ORDER BY ph.action_date DESC, ph.personnel_history_id DESC;
$$;

-- get the last registry of an user
CREATE OR REPLACE FUNCTION get_last_user_status(p_user_id UUID)
RETURNS UUID
LANGUAGE sql AS $$
    SELECT ph.personnel_history_id FROM personnel_history ph WHERE ph.user_id = p_user_id ORDER BY ph.action_date DESC, ph.personnel_history_id DESC LIMIT 1;
$$;

-- get the registry of an specific daycare
CREATE OR REPLACE FUNCTION get_daycare_personnel_history(p_daycare_id UUID)
RETURNS TABLE (personnel_history_id UUID)
LANGUAGE sql AS $$
    SELECT ph.personnel_history_id FROM personnel_history ph JOIN users u ON u.user_id = ph.user_id WHERE u.daycare_id = p_daycare_id ORDER BY ph.action_date DESC, ph.personnel_history_id DESC;
$$;
