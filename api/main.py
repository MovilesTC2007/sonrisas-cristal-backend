import os

import psycopg
from fastapi import FastAPI, HTTPException

app = FastAPI()

DATABASE_URL = os.environ.get("DATABASE_URL")


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/health/db")
def health_db():
    try:
        with psycopg.connect(DATABASE_URL, connect_timeout=5) as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        return {"status": "ok"}
    except psycopg.Error as e:
        raise HTTPException(status_code=503, detail=f"database unreachable: {e}") from e


@app.get("/auth-check")
def auth_check():
    password = "password123"
    wrong_password = "password121"
    mail = "authtest@gmail.com"

    try:
        with psycopg.connect(DATABASE_URL, connect_timeout=5) as conn, conn.cursor() as cur:

            # crete a new user
            cur.execute(
                "SELECT add_user(%s, %s, %s, %s, %s, %s, %s, %s)",
                (1, "Authentication", "Test", password, mail, 1, 1, True)
            )

            id = cur.fetchone()[0]

            # see the hashed password of lenght 60 ()
            cur.execute("SELECT password_hash FROM users WHERE user_id = %s", (id,))
            condimented_password = cur.fetchone()[0]

            # log in with right and wrong password
            cur.execute("SELECT authenticate(%s, %s)", (mail, password))
            ok_id = cur.fetchone()[0]
            cur.execute("SELECT authenticate(%s, %s)", (mail, wrong_password))
            bad_id = cur.fetchone()[0]

            # clean the test
            cur.execute("DELETE FROM users WHERE user_id = %s", (id,))
            conn.commit()

    except (psycopg.Error, TypeError) as e:
        raise HTTPException(status_code=503, detail=f"check failed: {type(e).__name__}")

    passed = (ok_id == id and bad_id is None)
    return {
        "passed": passed,
        "created_user_id": id,
        "login_correct_password": ok_id == id,
        "login_wrong_password_rejected": bad_id is None,
        # bcrypt($2a$) - 4 | cost factor(12) - 2 | separator($) - 1 | salt(,,,/,,,.,,,) - 22 | hash(...) - 31
        "hash_prefix": condimented_password[:7], # expect "$2a$12$"
        "hash_length": len(condimented_password), # expect 60
        "password_not_stored_plain": password not in condimented_password,
    }


@app.get("/hash-list")
def hash_list():
    try:
        with psycopg.connect(DATABASE_URL, connect_timeout=5) as conn, conn.cursor() as cur:
            cur.execute("SELECT email, password_hash FROM users ORDER BY user_id")
            rows = cur.fetchall()
    except psycopg.Error as e:
        raise HTTPException(status_code=503, detail=f"check failed: {type(e).__name__}: {e}")

    return [{"email": email, "hash": h} for email, h in rows]


REQUIRED_FUNCTIONS = [
    "get_roles_description",
    "get_position_description",
    "generate_invitation_code",
    "redeem_invitation_code",
    "get_area_by_id",
    "get_daycare_areas",
    "add_area",
    "modify_area",
    "get_daycare_by_id",
    "add_daycare",
    "modify_daycare",
    "get_active_personnel",
    "get_user_by_id",
    "get_area_personnel",
    "modify_user",
    "authenticate",
    "add_user",
    "get_request_by_id",
    "get_user_requests",
    "add_request",
    "modify_shift",
    "add_shift",
    "get_shift_data_by_id",
    "get_user_current_shift_days",
    "get_users_in_shift_by_daycare",
    "get_users_in_day_by_daycare",
    "get_user_attendances",
    "add_attendance",
    "modify_attendance",
    "get_attendance_in_daycare_by_current_shift",
    "get_attendance_in_daycare_by_day",
    "add_personnel_history",
    "modify_personnel_history",
    "get_personnel_history_by_id",
    "get_user_history",
    "get_last_user_status",
    "get_daycare_personnel_history",
]

@app.get("/health/endpoints")
def health_endpoints():
    try:
        with psycopg.connect(DATABASE_URL, connect_timeout=5) as conn, conn.cursor() as cur:
            cur.execute(
                "SELECT proname "
                "FROM pg_proc p "
                "JOIN pg_namespace n ON n.oid = p.pronamespace "
                "WHERE n.nspname = 'public' AND proname = ANY(%s)",
                (REQUIRED_FUNCTIONS,),
            )
            found = {r[0] for r in cur.fetchall()}
        missing = sorted(set(REQUIRED_FUNCTIONS) - found)
        if missing:
            raise HTTPException(status_code=503, detail=f"missing functions: {missing}")
        return {"status": "ok"}
    except psycopg.Error as e:
        raise HTTPException(status_code=503, detail=f"endpoints error: {e}") from e