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
-- invitation_code
-- ---------------------------------------------------------------------------
INSERT INTO invitation_code (daycare_id, code, role_id, expires_at, max_uses)
SELECT d.daycare_id, 'ABC123', r.role_id, now() + INTERVAL '30 days', 10
FROM daycare d, roles r
WHERE d.name = 'Sonrisas Cristal - Apodaca' AND r.description = 'staff'
UNION ALL
SELECT d.daycare_id, 'ADM001', r.role_id, now() + INTERVAL '7 days', 1
FROM daycare d, roles r
WHERE d.name = 'Sonrisas Cristal - Apodaca' AND r.description = 'director'
UNION ALL
SELECT d.daycare_id, 'NORTE1', r.role_id, now() + INTERVAL '30 days', 5
FROM daycare d, roles r
WHERE d.name = 'Sonrisas Cristal - Norte' AND r.description = 'staff';

-- ---------------------------------------------------------------------------
-- users
-- NOTE: password_hash values below are placeholder strings, NOT real bcrypt
-- hashes of any actual password. Replace with real hashes if you need to log
-- in through the app using this seed.
-- ---------------------------------------------------------------------------
INSERT INTO users (daycare_id, name, lastname, email, password_hash, role, position, is_active)
SELECT d.daycare_id, 'Laura', 'Gómez', 'laura.gomez@sonrisascristal.com', '$2b$12$seedhashplaceholder0000000000000000000000000', r.role_id, p.position_id, TRUE
FROM daycare d, roles r, positions p
WHERE d.name = 'Sonrisas Cristal - Apodaca' AND r.description = 'director' AND p.description = 'director'
UNION ALL
SELECT d.daycare_id, 'Marta', 'Pérez', 'marta.perez@sonrisascristal.com', '$2b$12$seedhashplaceholder0000000000000000000000001', r.role_id, p.position_id, TRUE
FROM daycare d, roles r, positions p
WHERE d.name = 'Sonrisas Cristal - Apodaca' AND r.description = 'staff' AND p.description = 'profesor'
UNION ALL
SELECT d.daycare_id, 'Diego', 'Hernández', 'diego.hernandez@sonrisascristal.com', '$2b$12$seedhashplaceholder0000000000000000000000002', r.role_id, p.position_id, TRUE
FROM daycare d, roles r, positions p
WHERE d.name = 'Sonrisas Cristal - Apodaca' AND r.description = 'staff' AND p.description = 'profesor'
UNION ALL
SELECT d.daycare_id, 'Sofía', 'Ramírez', 'sofia.ramirez@sonrisascristal.com', '$2b$12$seedhashplaceholder0000000000000000000000003', r.role_id, p.position_id, TRUE
FROM daycare d, roles r, positions p
WHERE d.name = 'Sonrisas Cristal - Apodaca' AND r.description = 'staff' AND p.description = 'asistente'
UNION ALL
SELECT d.daycare_id, 'Carlos', 'Ibarra', 'carlos.ibarra@sonrisascristal.com', '$2b$12$seedhashplaceholder0000000000000000000000004', r.role_id, p.position_id, FALSE
FROM daycare d, roles r, positions p
WHERE d.name = 'Sonrisas Cristal - Apodaca' AND r.description = 'staff' AND p.description = 'asistente'
UNION ALL
SELECT d.daycare_id, 'Patricia', 'Luna', 'patricia.luna@sonrisascristal.com', '$2b$12$seedhashplaceholder0000000000000000000000005', r.role_id, p.position_id, TRUE
FROM daycare d, roles r, positions p
WHERE d.name = 'Sonrisas Cristal - Norte' AND r.description = 'director' AND p.description = 'director'
UNION ALL
SELECT d.daycare_id, 'Jorge', 'Salinas', 'jorge.salinas@sonrisascristal.com', '$2b$12$seedhashplaceholder0000000000000000000000006', r.role_id, p.position_id, TRUE
FROM daycare d, roles r, positions p
WHERE d.name = 'Sonrisas Cristal - Norte' AND r.description = 'staff' AND p.description = 'profesor';

-- ---------------------------------------------------------------------------
-- shift (Mon-Fri, workday 1..5, open-ended — valid_until NULL means "current")
-- ---------------------------------------------------------------------------
INSERT INTO shift (area_id, user_id, entry_hour, exit_hour, workday, valid_from, valid_until, is_active)
SELECT a.area_id, u.user_id, '08:00'::time, '16:00'::time, wd.workday, CURRENT_DATE - INTERVAL '30 days', NULL::date, TRUE
FROM users u
JOIN area a ON a.name = 'Lactantes' AND a.daycare_id = u.daycare_id
CROSS JOIN generate_series(1, 5) AS wd(workday)
WHERE u.email = 'marta.perez@sonrisascristal.com'
UNION ALL
SELECT a.area_id, u.user_id, '08:00'::time, '16:00'::time, wd.workday, CURRENT_DATE - INTERVAL '30 days', NULL::date, TRUE
FROM users u
JOIN area a ON a.name = 'Maternal' AND a.daycare_id = u.daycare_id
CROSS JOIN generate_series(1, 5) AS wd(workday)
WHERE u.email = 'diego.hernandez@sonrisascristal.com'
UNION ALL
SELECT a.area_id, u.user_id, '09:00'::time, '17:00'::time, wd.workday, CURRENT_DATE - INTERVAL '30 days', NULL::date, TRUE
FROM users u
JOIN area a ON a.name = 'Preescolar' AND a.daycare_id = u.daycare_id
CROSS JOIN generate_series(1, 5) AS wd(workday)
WHERE u.email = 'sofia.ramirez@sonrisascristal.com'
UNION ALL
SELECT a.area_id, u.user_id, '07:30'::time, '15:30'::time, wd.workday, CURRENT_DATE - INTERVAL '30 days', NULL::date, TRUE
FROM users u
JOIN area a ON a.name = 'Lactantes' AND a.daycare_id = u.daycare_id
CROSS JOIN generate_series(1, 5) AS wd(workday)
WHERE u.email = 'jorge.salinas@sonrisascristal.com';

-- ---------------------------------------------------------------------------
-- attendance
-- shift_id is resolved by matching the user's shift whose workday equals the
-- day-of-week of attendance_date (Postgres EXTRACT(DOW ...) uses the same
-- 0=Sun..6=Sat convention as the workday column).
-- ---------------------------------------------------------------------------
INSERT INTO attendance (user_id, shift_id, attendance_date, check_in, check_out, status, notes, registered_by)
SELECT u.user_id, s.shift_id, d.attendance_date, d.check_in, d.check_out, d.status, d.notes, u.user_id
FROM users u
JOIN LATERAL (
    VALUES
        (DATE '2026-11-02', TIMESTAMPTZ '2026-11-02 07:58:00-06', TIMESTAMPTZ '2026-11-02 16:05:00-06', 'on_time', NULL),
        (DATE '2026-11-03', TIMESTAMPTZ '2026-11-03 08:15:00-06', TIMESTAMPTZ '2026-11-03 16:00:00-06', 'late', 'Tráfico'),
        (DATE '2026-11-04', TIMESTAMPTZ '2026-11-04 07:55:00-06', TIMESTAMPTZ '2026-11-04 16:02:00-06', 'on_time', NULL),
        (DATE '2026-11-05', NULL, NULL, 'absent', 'Enfermedad, justificada'),
        (DATE '2026-11-06', TIMESTAMPTZ '2026-11-06 07:57:00-06', TIMESTAMPTZ '2026-11-06 16:01:00-06', 'on_time', NULL)
) AS d(attendance_date, check_in, check_out, status, notes) ON TRUE
JOIN shift s ON s.user_id = u.user_id AND s.workday = EXTRACT(DOW FROM d.attendance_date)::smallint
WHERE u.email = 'marta.perez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, s.shift_id, d.attendance_date, d.check_in, d.check_out, d.status, d.notes, u.user_id
FROM users u
JOIN LATERAL (
    VALUES
        (DATE '2026-11-02', TIMESTAMPTZ '2026-11-02 08:00:00-06', TIMESTAMPTZ '2026-11-02 16:00:00-06', 'on_time', NULL),
        (DATE '2026-11-03', TIMESTAMPTZ '2026-11-03 08:05:00-06', TIMESTAMPTZ '2026-11-03 15:50:00-06', 'late', NULL)
) AS d(attendance_date, check_in, check_out, status, notes) ON TRUE
JOIN shift s ON s.user_id = u.user_id AND s.workday = EXTRACT(DOW FROM d.attendance_date)::smallint
WHERE u.email = 'diego.hernandez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, s.shift_id, d.attendance_date, d.check_in, d.check_out, d.status, d.notes, u.user_id
FROM users u
JOIN LATERAL (
    VALUES
        (DATE '2026-11-02', TIMESTAMPTZ '2026-11-02 07:28:00-06', TIMESTAMPTZ '2026-11-02 15:31:00-06', 'on_time', NULL),
        (DATE '2026-11-03', TIMESTAMPTZ '2026-11-03 07:29:00-06', TIMESTAMPTZ '2026-11-03 15:35:00-06', 'on_time', NULL)
) AS d(attendance_date, check_in, check_out, status, notes) ON TRUE
JOIN shift s ON s.user_id = u.user_id AND s.workday = EXTRACT(DOW FROM d.attendance_date)::smallint
WHERE u.email = 'jorge.salinas@sonrisascristal.com';

-- ---------------------------------------------------------------------------
-- requests
-- ---------------------------------------------------------------------------
INSERT INTO requests (user_id, type, status, request_date, resolved_at, resolved_by, notes)
SELECT u.user_id, 'permiso', 'approved', now() - INTERVAL '5 days', now() - INTERVAL '4 days', admin.user_id, 'Permiso médico'
FROM users u, users admin
WHERE u.email = 'marta.perez@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'cambio_turno', 'pending', now() - INTERVAL '1 day', NULL, NULL, 'Solicita cambiar a turno de Preescolar'
FROM users u
WHERE u.email = 'diego.hernandez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'vacaciones', 'rejected', now() - INTERVAL '10 days', now() - INTERVAL '9 days', admin.user_id, 'Periodo saturado, se reagenda para el siguiente trimestre'
FROM users u, users admin
WHERE u.email = 'sofia.ramirez@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com';

-- ---------------------------------------------------------------------------
-- personnel_history
-- ---------------------------------------------------------------------------
INSERT INTO personnel_history (user_id, action, previous_value, new_value, action_date, notes, changed_by)
SELECT u.user_id, 'Hired', NULL, 'teacher', CURRENT_DATE - INTERVAL '30 days', 'Alta inicial', admin.user_id
FROM users u, users admin
WHERE u.email = 'marta.perez@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Hired', NULL, 'teacher', CURRENT_DATE - INTERVAL '30 days', 'Alta inicial', admin.user_id
FROM users u, users admin
WHERE u.email = 'diego.hernandez@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Hired', NULL, 'assistant', CURRENT_DATE - INTERVAL '30 days', 'Alta inicial', admin.user_id
FROM users u, users admin
WHERE u.email = 'sofia.ramirez@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Hired', NULL, 'assistant', CURRENT_DATE - INTERVAL '60 days', 'Alta inicial', admin.user_id
FROM users u, users admin
WHERE u.email = 'carlos.ibarra@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Terminated', 'active', 'inactive', CURRENT_DATE - INTERVAL '2 days', 'Renuncia voluntaria', admin.user_id
FROM users u, users admin
WHERE u.email = 'carlos.ibarra@sonrisascristal.com' AND admin.email = 'laura.gomez@sonrisascristal.com'
UNION ALL
SELECT u.user_id, 'Hired', NULL, 'teacher', CURRENT_DATE - INTERVAL '20 days', 'Alta inicial', admin.user_id
FROM users u, users admin
WHERE u.email = 'jorge.salinas@sonrisascristal.com' AND admin.email = 'patricia.luna@sonrisascristal.com';

COMMIT;
