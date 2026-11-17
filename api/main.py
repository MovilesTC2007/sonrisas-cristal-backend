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