-- POSTGRESQL
-- Seed data for local/dev use. Run this AFTER tables.sql, against the same fresh database.
-- Lookups use natural keys (names/emails) instead of hardcoded ids, since IDENTITY ids
-- depend on insertion order and shouldn't be assumed.

BEGIN;

-- ---------------------------------------------------------------------------
-- roles / positions
-- ---------------------------------------------------------------------------
INSERT INTO roles (description) VALUES
    ('director'),
    ('encargado'),
    ('staff');

INSERT INTO positions (description) VALUES
    ('director'),
    ('encargado'),
    ('profesor'),
    ('limpieza'),
    ('asistente');

-- ---------------------------------------------------------------------------
-- daycare / area
-- ---------------------------------------------------------------------------
INSERT INTO daycare (name, address, tolerance_minutes) VALUES
    ('Sonrisas Cristal - Apodaca', 'Av. Apodaca 123, Apodaca', 10),
    ('Sonrisas Cristal - Norte', 'Calle Pino 45, Monterrey', 5);

INSERT INTO area (daycare_id, name, minimum_active_staff)
SELECT daycare_id, 'Lactantes', 2 FROM daycare WHERE name = 'Sonrisas Cristal - Apodaca'
UNION ALL
SELECT daycare_id, 'Maternal', 2 FROM daycare WHERE name = 'Sonrisas Cristal - Apodaca'
UNION ALL
SELECT daycare_id, 'Preescolar', 1 FROM daycare WHERE name = 'Sonrisas Cristal - Apodaca'
UNION ALL
SELECT daycare_id, 'Lactantes', 1 FROM daycare WHERE name = 'Sonrisas Cristal - Norte'
UNION ALL
SELECT daycare_id, 'Maternal', 1 FROM daycare WHERE name = 'Sonrisas Cristal - Norte';

-- ---------------------------------------------------------------------------
-- invitation codes
-- ---------------------------------------------------------------------------
-- name/lastname/position_id/is_active are the predefined fields the invitee
-- inherits on redemption (see redeem_invitation_code); the invitee only ever
-- supplies their own email/password.
INSERT INTO invitation_code (daycare_id, code, role_id, position_id, name, lastname, is_active, expires_at)
SELECT d.daycare_id, 'ABC123', r.role_id, p.position_id, 'Lucía', 'Torres', TRUE, now() + INTERVAL '30 days'
FROM daycare d, roles r, positions p
WHERE d.name = 'Sonrisas Cristal - Apodaca' AND r.description = 'staff' AND p.description = 'profesor'
UNION ALL
SELECT d.daycare_id, 'ADM001', r.role_id, p.position_id, 'Andrés', 'Mendoza', TRUE, now() + INTERVAL '7 days'
FROM daycare d, roles r, positions p
WHERE d.name = 'Sonrisas Cristal - Apodaca' AND r.description = 'director' AND p.description = 'director'
UNION ALL
SELECT d.daycare_id, 'NORTE1', r.role_id, p.position_id, 'Valeria', 'Cruz', TRUE, now() + INTERVAL '30 days'
FROM daycare d, roles r, positions p
WHERE d.name = 'Sonrisas Cristal - Norte' AND r.description = 'staff' AND p.description = 'asistente';

-- ---------------------------------------------------------------------------
-- users
-- NOTE: password_hash values below are placeholder strings, NOT real bcrypt
-- hashes of any actual password. Replace with real hashes if you need to log
-- in through the app using this seed.
-- ---------------------------------------------------------------------------
-- Seed users through add_user() so hashes are properly peppered + salted.
-- All seed users share the dev password 'Test1234!'. Development only.
-- Requires: schema -> functions.sql -> this file (in that order).

SELECT add_user(
    (SELECT daycare_id FROM daycare WHERE name = 'Sonrisas Cristal - Apodaca'),
    'Laura', 'Gómez', 'Test1234!', 'laura.gomez@sonrisascristal.com',
    (SELECT role_id FROM roles WHERE description = 'director'),
    (SELECT position_id FROM positions WHERE description = 'director'),
    TRUE);

SELECT add_user(
    (SELECT daycare_id FROM daycare WHERE name = 'Sonrisas Cristal - Apodaca'),
    'Marta', 'Pérez', 'Test1234!', 'marta.perez@sonrisascristal.com',
    (SELECT role_id FROM roles WHERE description = 'staff'),
    (SELECT position_id FROM positions WHERE description = 'profesor'),
    TRUE);

SELECT add_user(
    (SELECT daycare_id FROM daycare WHERE name = 'Sonrisas Cristal - Apodaca'),
    'Diego', 'Hernández', 'Test1234!', 'diego.hernandez@sonrisascristal.com',
    (SELECT role_id FROM roles WHERE description = 'encargado'),
    (SELECT position_id FROM positions WHERE description = 'encargado'),
    TRUE);

SELECT add_user(
    (SELECT daycare_id FROM daycare WHERE name = 'Sonrisas Cristal - Apodaca'),
    'Sofía', 'Ramírez', 'Test1234!', 'sofia.ramirez@sonrisascristal.com',
    (SELECT role_id FROM roles WHERE description = 'staff'),
    (SELECT position_id FROM positions WHERE description = 'asistente'),
    TRUE);

SELECT add_user(
    (SELECT daycare_id FROM daycare WHERE name = 'Sonrisas Cristal - Apodaca'),
    'Carlos', 'Ibarra', 'Test1234!', 'carlos.ibarra@sonrisascristal.com',
    (SELECT role_id FROM roles WHERE description = 'staff'),
    (SELECT position_id FROM positions WHERE description = 'asistente'),
    FALSE);

SELECT add_user(
    (SELECT daycare_id FROM daycare WHERE name = 'Sonrisas Cristal - Norte'),
    'Patricia', 'Luna', 'Test1234!', 'patricia.luna@sonrisascristal.com',
    (SELECT role_id FROM roles WHERE description = 'director'),
    (SELECT position_id FROM positions WHERE description = 'director'),
    TRUE);

SELECT add_user(
    (SELECT daycare_id FROM daycare WHERE name = 'Sonrisas Cristal - Norte'),
    'Jorge', 'Salinas', 'Test1234!', 'jorge.salinas@sonrisascristal.com',
    (SELECT role_id FROM roles WHERE description = 'staff'),
    (SELECT position_id FROM positions WHERE description = 'profesor'),
    TRUE);
    
-- ---------------------------------------------------------------------------
-- shift (Mon-Fri, workday 1..5, open-ended — valid_until NULL means "current")
-- ---------------------------------------------------------------------------
INSERT INTO shift (area_id, user_id, entry_hour, exit_hour, workday, valid_from, valid_until, is_active)
SELECT a.area_id, u.user_id, '08:00'::time, '16:00'::time, wd.workday, CURRENT_DATE - 30, NULL::date, TRUE
FROM users u
JOIN area a ON a.name = 'Lactantes' AND a.daycare_id = u.daycare_id
CROSS JOIN generate_series(1, 5) AS wd(workday)
WHERE u.email = 'marta.perez@sonrisascristal.com'
UNION ALL
SELECT a.area_id, u.user_id, '08:00'::time, '16:00'::time, wd.workday, CURRENT_DATE - 30, NULL::date, TRUE
FROM users u
JOIN area a ON a.name = 'Maternal' AND a.daycare_id = u.daycare_id
CROSS JOIN generate_series(1, 5) AS wd(workday)
WHERE u.email = 'diego.hernandez@sonrisascristal.com'
UNION ALL
SELECT a.area_id, u.user_id, '09:00'::time, '17:00'::time, wd.workday, CURRENT_DATE - 30, NULL::date, TRUE
FROM users u
JOIN area a ON a.name = 'Preescolar' AND a.daycare_id = u.daycare_id
CROSS JOIN generate_series(1, 5) AS wd(workday)
WHERE u.email = 'sofia.ramirez@sonrisascristal.com'
UNION ALL
SELECT a.area_id, u.user_id, '07:30'::time, '15:30'::time, wd.workday, CURRENT_DATE - 30, NULL::date, TRUE
FROM users u
JOIN area a ON a.name = 'Lactantes' AND a.daycare_id = u.daycare_id
CROSS JOIN generate_series(1, 5) AS wd(workday)
WHERE u.email = 'jorge.salinas@sonrisascristal.com';

-- ---------------------------------------------------------------------------
-- attendance
-- shift_id is resolved by matching the user's shift whose workday equals the
-- day-of-week of attendance_date (Postgres EXTRACT(DOW ...) uses the same
-- 0=Sun..6=Sat convention as the workday column).
-- uuid is now required (NOT NULL UNIQUE); generated per row.
-- ---------------------------------------------------------------------------
INSERT INTO attendance (user_id, shift_id, attendance_date, check_in, check_out, status, notes, registered_by, uuid)
SELECT u.user_id, s.shift_id, d.attendance_date, d.check_in, d.check_out, d.status, d.notes, u.user_id, gen_random_uuid()::text
FROM users u
JOIN LATERAL (
    VALUES
        (DATE '2026-11-02', TIMESTAMPTZ '2026-11-02 07:58:00-06', TIMESTAMPTZ '2026-11-02 16:05:00-06', 'Attended'::status_of_attendance, NULL),
        (DATE '2026-11-03', TIMESTAMPTZ '2026-11-03 08:15:00-06', TIMESTAMPTZ '2026-11-03 16:00:00-06', 'Late'::status_of_attendance, 'Tráfico'),
        (DATE '2026-11-04', TIMESTAMPTZ '2026-11-04 07:55:00-06', TIMESTAMPTZ '2026-11-04 16:02:00-06', 'Attended'::status_of_attendance, NULL),
        (DATE '2026-11-05', NULL, NULL, 'Absent'::status_of_attendance, 'Enfermedad, justificada'),
        (DATE '2026-11-06', TIMESTAMPTZ '2026-11-06 07:57:00-06', TIMESTAMPTZ '2026-11-06 16:01:00-06', 'Attended'::status_of_attendance, NULL)
) AS d(attendance_date, check_in, check_out, status, notes) ON TRUE
JOIN shift s ON s.user_id = u.user_id AND s.workday = EXTRACT(DOW FROM d.attendance_date)::smallint
WHERE u.email = 'marta.perez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, s.shift_id, d.attendance_date, d.check_in, d.check_out, d.status, d.notes, u.user_id, gen_random_uuid()::text
FROM users u
JOIN LATERAL (
    VALUES
        (DATE '2026-11-02', TIMESTAMPTZ '2026-11-02 08:00:00-06', TIMESTAMPTZ '2026-11-02 16:00:00-06', 'Attended'::status_of_attendance, NULL),
        (DATE '2026-11-03', TIMESTAMPTZ '2026-11-03 08:05:00-06', TIMESTAMPTZ '2026-11-03 15:50:00-06', 'Left Early'::status_of_attendance, 'Salida anticipada')
) AS d(attendance_date, check_in, check_out, status, notes) ON TRUE
JOIN shift s ON s.user_id = u.user_id AND s.workday = EXTRACT(DOW FROM d.attendance_date)::smallint
WHERE u.email = 'diego.hernandez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, s.shift_id, d.attendance_date, d.check_in, d.check_out, d.status, d.notes, u.user_id, gen_random_uuid()::text
FROM users u
JOIN LATERAL (
    VALUES
        (DATE '2026-11-02', TIMESTAMPTZ '2026-11-02 07:28:00-06', TIMESTAMPTZ '2026-11-02 15:31:00-06', 'Attended'::status_of_attendance, NULL),
        (DATE '2026-11-03', TIMESTAMPTZ '2026-11-03 07:29:00-06', TIMESTAMPTZ '2026-11-03 15:35:00-06', 'Attended'::status_of_attendance, NULL)
) AS d(attendance_date, check_in, check_out, status, notes) ON TRUE
JOIN shift s ON s.user_id = u.user_id AND s.workday = EXTRACT(DOW FROM d.attendance_date)::smallint
WHERE u.email = 'jorge.salinas@sonrisascristal.com';

-- ---------------------------------------------------------------------------
-- requests
-- ---------------------------------------------------------------------------
INSERT INTO requests (user_id, type, status, request_date, resolved_at, resolved_by, notes)
SELECT u.user_id, 'Sick Leave'::types_of_requests, 'Approved'::status_of_requests,
       now() - INTERVAL '5 days', now() - INTERVAL '4 days', admin.user_id, 'Permiso médico'
FROM users u, users admin
WHERE u.email = 'marta.perez@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Personal Leave'::types_of_requests, 'Pending'::status_of_requests,
       now() - INTERVAL '1 day', NULL, NULL, 'Solicita cambiar a turno de Preescolar'
FROM users u
WHERE u.email = 'diego.hernandez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Vacation'::types_of_requests, 'Rejected'::status_of_requests,
       now() - INTERVAL '10 days', now() - INTERVAL '9 days', admin.user_id, 'Periodo saturado, se reagenda para el siguiente trimestre'
FROM users u, users admin
WHERE u.email = 'sofia.ramirez@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com';

-- ---------------------------------------------------------------------------
-- personnel_history (previous_value / new_value ya no existen; se pasan a notes)
-- ---------------------------------------------------------------------------
INSERT INTO personnel_history (user_id, action, action_date, notes, changed_by)
SELECT u.user_id, 'Hired', CURRENT_DATE - 30, 'Alta inicial. Puesto: profesor', admin.user_id
FROM users u, users admin
WHERE u.email = 'marta.perez@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Hired', CURRENT_DATE - 30, 'Alta inicial. Puesto: profesor', admin.user_id
FROM users u, users admin
WHERE u.email = 'diego.hernandez@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Hired', CURRENT_DATE - 30, 'Alta inicial. Puesto: asistente', admin.user_id
FROM users u, users admin
WHERE u.email = 'sofia.ramirez@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Hired', CURRENT_DATE - 60, 'Alta inicial. Puesto: asistente', admin.user_id
FROM users u, users admin
WHERE u.email = 'carlos.ibarra@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Terminated', CURRENT_DATE - 2, 'Renuncia voluntaria (activo -> inactivo)', admin.user_id
FROM users u, users admin
WHERE u.email = 'carlos.ibarra@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Hired', CURRENT_DATE - 20, 'Alta inicial. Puesto: profesor', admin.user_id
FROM users u, users admin
WHERE u.email = 'jorge.salinas@sonrisascristal.com' AND admin.email = 'patricia.luna@sonrisascristal.com';

COMMIT;