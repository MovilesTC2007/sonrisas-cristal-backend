-- POSTGRESQL
-- NOTE: Snake case and lowercase names for identities on this database

-- CREATE EXTENSION IF NOT EXISTS btree_gist; -- needed for the EXCLUDE constraint on shift (overlap check)

DROP TABLE IF EXISTS personnel_history CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS shift CASCADE;
DROP TABLE IF EXISTS requests CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS invitation_code CASCADE;
DROP TABLE IF EXISTS area CASCADE;
DROP TABLE IF EXISTS daycare CASCADE;
DROP TABLE IF EXISTS positions CASCADE;
DROP TABLE IF EXISTS roles CASCADE;


-- For security reasons we decided to use UUIDs instead of INT and in the version v4 
-- because they are generated randomly and are not sequential, making it harder to guess the next value.

CREATE TABLE roles( -- Encargado, director, empleado, which is the hierarchy in the app permissions
    role_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    description TEXT NOT NULL UNIQUE
);

CREATE TABLE positions( -- Exact charge for the person
    position_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    description TEXT NOT NULL UNIQUE
);

CREATE TABLE daycare (
    daycare_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    tolerance_minutes INT NOT NULL DEFAULT 5,
    low_delay INT NOT NULL DEFAULT 5,
    medium_delay INT NOT NULL DEFAULT 15,
    absence INT NOT NULL DEFAULT 30
);

CREATE TABLE area(
    area_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    daycare_id uuid NOT NULL,
    name TEXT NOT NULL,
    minimum_active_staff INT NOT NULL DEFAULT 0,

    FOREIGN KEY (daycare_id) REFERENCES daycare(daycare_id) ON DELETE RESTRICT
);

CREATE TABLE invitation_code(
    code_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    daycare_id uuid NOT NULL,
    code TEXT NOT NULL UNIQUE CHECK (LENGTH(code) <= 6),
    role_id uuid REFERENCES roles(role_id),
    position_id uuid REFERENCES positions(position_id),
    name TEXT NOT NULL,
    lastname TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    FOREIGN KEY (daycare_id) REFERENCES daycare(daycare_id) ON DELETE RESTRICT
); 

CREATE TABLE users(
    user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    daycare_id uuid NOT NULL,
    name TEXT NOT NULL,
    lastname TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE CHECK (LENGTH(email) < 100),
    password_hash TEXT NOT NULL,
    role_id uuid REFERENCES roles(role_id), -- Encargado, director, empleado
    position_id uuid REFERENCES positions(position_id),
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    FOREIGN KEY (daycare_id) REFERENCES daycare(daycare_id) ON DELETE RESTRICT
);

-- Case-insensitive uniqueness: "Ana@x.com" and "ana@x.com" must be the same account.
CREATE UNIQUE INDEX users_email_lower_key ON users (lower(email));

-- Persistent JWT logout list (survives API restarts, shared across workers/containers).
-- Only jti is stored, never the token itself.
CREATE TABLE revoked_token(
    jti TEXT PRIMARY KEY,
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE TYPE types_of_requests AS ENUM ('Vacation', 'Sick Leave', 'Personal Leave'); -- Add more later
CREATE TYPE status_of_requests AS ENUM ('Pending', 'Approved', 'Rejected'); -- Add more later
CREATE TABLE requests(
    request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    type types_of_requests NOT NULL,
    status status_of_requests NOT NULL DEFAULT 'Pending',
    request_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ DEFAULT NULL,
    resolved_by uuid, -- who approved/rejected it
    notes TEXT,  -- Justification, observations, permissions, etc

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (resolved_by) REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE shift(
    shift_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    area_id uuid NOT NULL, -- Area where the user has to be
    user_id uuid NOT NULL,
    entry_hour TIME NOT NULL,
    exit_hour TIME NOT NULL,
    workday SMALLINT NOT NULL CHECK (workday BETWEEN 0 AND 6), --0=Dom, 1=Lun... 6=Sab. One registry per day that each person has to work
    valid_from DATE,
    valid_until DATE,
    is_active BOOLEAN DEFAULT FALSE,
    request_id uuid, -- approved rotation/shift-change request that produced this shift version, if any
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    FOREIGN KEY (area_id) REFERENCES area(area_id) ON DELETE RESTRICT,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (request_id) REFERENCES requests(request_id) ON DELETE SET NULL

    /* Take care of overlapping shifts
    CONSTRAINT shift_no_overlap EXCLUDE USING gist (
        user_id WITH =,
        workday WITH =,
        daterange(valid_from, valid_until, '[]') WITH &&
    )
    */
);

CREATE TYPE status_of_attendance AS ENUM ('Attended', 'Late', 'Absent', 'Left Early');
CREATE TABLE attendance(
    attendance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    shift_id uuid NOT NULL,

    attendance_date DATE NOT NULL,
    check_in TIMESTAMPTZ,
    check_out TIMESTAMPTZ,
    status status_of_attendance,
    notes TEXT,  -- Justification, observations, permissions, etc
    registered_by uuid NOT NULL,
    uuid TEXT NOT NULL UNIQUE,

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (shift_id) REFERENCES shift(shift_id) ON DELETE RESTRICT,
    UNIQUE (shift_id, attendance_date),
    FOREIGN KEY (registered_by) REFERENCES users(user_id) ON DELETE RESTRICT
);

CREATE TABLE personnel_history(
    personnel_history_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    action TEXT NOT NULL, -- Hired, Promoted, Demoted, Terminated, Role changed, Position changed, etc
    action_date DATE NOT NULL,
    notes TEXT,  -- Justification, observations, permissions, etc
    changed_by uuid NOT NULL,

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (changed_by) REFERENCES users(user_id) ON DELETE RESTRICT
);
