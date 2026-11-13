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

CREATE TABLE roles( -- Encargado, director, empleado, which is the hierarchy in the app permissions
    role_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    description TEXT NOT NULL UNIQUE
);

CREATE TABLE positions( -- Exact charge for the person
    position_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    description TEXT NOT NULL UNIQUE
);

CREATE TABLE daycare (
    daycare_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    tolerance_minutes INT NOT NULL DEFAULT 5
);

CREATE TABLE area(
    area_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    daycare_id INT NOT NULL,
    name TEXT NOT NULL,
    minimum_active_staff INT NOT NULL DEFAULT 0,

    FOREIGN KEY (daycare_id) REFERENCES daycare(daycare_id) ON DELETE RESTRICT
);

CREATE TABLE invitation_code(
    code_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    daycare_id INT NOT NULL,
    code TEXT NOT NULL UNIQUE CHECK (LENGTH(code) <= 6),
    role_id INT REFERENCES roles(role_id),
    expires_at TIMESTAMP NOT NULL,
    times_used INT NOT NULL DEFAULT 0,
    max_uses INT, -- NULL = unlimited uses; otherwise enforce times_used <= max_uses at the app layer
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    FOREIGN KEY (daycare_id) REFERENCES daycare(daycare_id) ON DELETE RESTRICT
); 

CREATE TABLE users(
    user_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    daycare_id INT NOT NULL,
    name TEXT NOT NULL,
    lastname TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE CHECK (LENGTH(email) < 100),
    password_hash TEXT NOT NULL,
    role INT REFERENCES roles(role_id), -- Encargado, director, empleado
    position INT REFERENCES positions(position_id),
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    FOREIGN KEY (daycare_id) REFERENCES daycare(daycare_id) ON DELETE RESTRICT
);

CREATE TABLE requests(
    request_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT NOT NULL,
    type TEXT NOT NULL, -- Vacation, Sick Leave, Personal Leave, etc
    status TEXT, -- Pending, Approved, Rejected
    request_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ DEFAULT NULL,
    resolved_by INT, -- who approved/rejected it
    notes TEXT,  -- Justification, observations, permissions, etc

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (resolved_by) REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE shift(
    shift_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    area_id INT NOT NULL, -- Area where the user has to be
    user_id INT NOT NULL,
    entry_hour TIME NOT NULL,
    exit_hour TIME NOT NULL,
    workday SMALLINT NOT NULL CHECK (workday BETWEEN 0 AND 6), --0=Dom, 1=Lun... 6=Sab. One registry per day that each person has to work
    valid_from DATE,
    valid_until DATE,
    is_active BOOLEAN DEFAULT FALSE,
    request_id INT, -- approved rotation/shift-change request that produced this shift version, if any
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

CREATE TABLE attendance(
    attendance_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT NOT NULL,
    shift_id INT NOT NULL,

    attendance_date DATE NOT NULL,
    check_in TIMESTAMPTZ,
    check_out TIMESTAMPTZ,
    status TEXT, -- Attended, Late, Absent, Left Early, etc
    notes TEXT,  -- Justification, observations, permissions, etc
    registered_by INT NOT NULL,

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (shift_id) REFERENCES shift(shift_id) ON DELETE RESTRICT,
    UNIQUE (shift_id, attendance_date),
    FOREIGN KEY (registered_by) REFERENCES users(user_id) ON DELETE RESTRICT
);

CREATE TABLE personnel_history(
    personnel_history_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT NOT NULL,
    action TEXT NOT NULL, -- Hired, Promoted, Demoted, Terminated, Role changed, Position changed, etc
    previous_value TEXT, -- free text, e.g. previous role/position name. NULL when action has no prior state (e.g. "hired")
    new_value TEXT, -- free text, e.g. new role/position name
    action_date DATE NOT NULL,
    notes TEXT,  -- Justification, observations, permissions, etc
    changed_by INT NOT NULL,

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (changed_by) REFERENCES users(user_id) ON DELETE RESTRICT
);
