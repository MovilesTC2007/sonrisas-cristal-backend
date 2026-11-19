import os
from datetime import date, datetime, time, timezone
from typing import Literal

import psycopg
from fastapi import FastAPI, HTTPException, Query
from psycopg import errors as pgerr
from psycopg.rows import dict_row
from pydantic import BaseModel, Field

app = FastAPI(title="Sonrisas de Cristal API")

DATABASE_URL = os.environ.get("DATABASE_URL")

# Never send these columns to the client, even if a SQL function returns them.
SECRET_FIELDS = {"password_hash"}

RequestType = Literal["Vacation", "Sick Leave", "Personal Leave"]
RequestStatus = Literal["Pending", "Approved", "Rejected"]
AttendanceStatus = Literal["Attended", "Late", "Absent", "Left Early"]


# ---------------------------------------------------------------- helpers
def call(fn: str, *args) -> list[dict]:
    """Call a SQL function. `fn` is always a literal from this file (never user
    input) and every argument is bound as a parameter (RNFS-03)."""
    placeholders = ", ".join(["%s"] * len(args))
    try:
        with psycopg.connect(
            DATABASE_URL, row_factory=dict_row, connect_timeout=5
        ) as conn, conn.cursor() as cur:
            cur.execute(f"SELECT * FROM {fn}({placeholders})", args)
            rows = cur.fetchall()
    except pgerr.UniqueViolation:
        raise HTTPException(status_code=409, detail="Registro duplicado")
    except (
        pgerr.ForeignKeyViolation,
        pgerr.CheckViolation,
        pgerr.NotNullViolation,
        pgerr.InvalidTextRepresentation,
    ):
        raise HTTPException(status_code=400, detail="Datos inválidos")
    except pgerr.RaiseException as e:
        raise HTTPException(status_code=400, detail=e.diag.message_primary or "Solicitud rechazada")
    except psycopg.OperationalError:
        raise HTTPException(status_code=503, detail="Base de datos no disponible")
    except psycopg.Error:
        raise HTTPException(status_code=500, detail="Error interno")
    return [{k: v for k, v in r.items() if k not in SECRET_FIELDS} for r in rows]


def many(fn: str, *args) -> list[dict]:
    return call(fn, *args)


def one(fn: str, *args, status: int = 404, detail: str = "No encontrado") -> dict:
    rows = call(fn, *args)
    if not rows or all(v is None for v in rows[0].values()):
        raise HTTPException(status_code=status, detail=detail)
    return rows[0]


# ----------------------------------------------------------------- models
class LoginIn(BaseModel):
    email: str = Field(max_length=99)
    password: str = Field(min_length=1, max_length=200)


class RedeemIn(BaseModel):
    code: str = Field(min_length=1, max_length=6)


class InvitationIn(BaseModel):
    daycare_id: int
    role_id: int
    expires_at: datetime


class UserIn(BaseModel):
    daycare_id: int
    name: str = Field(min_length=1, max_length=100)
    lastname: str = Field(min_length=1, max_length=100)
    email: str = Field(max_length=99)
    role_id: int | None = None
    position_id: int | None = None
    is_active: bool = False


class DaycareIn(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    address: str = Field(min_length=1, max_length=300)
    low_delay: int = Field(ge=0)
    medium_delay: int = Field(ge=0)
    absence: int = Field(ge=0)


class AreaCreate(BaseModel):
    daycare_id: int
    name: str = Field(min_length=1, max_length=100)
    minimum_active_staff: int = Field(ge=0)


class AreaUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    minimum_active_staff: int = Field(ge=0)


class RequestIn(BaseModel):
    user_id: int
    type: RequestType
    status: RequestStatus = "Pending"
    request_date: datetime | None = None
    resolved_at: datetime | None = None
    resolved_by: int | None = None
    notes: str | None = Field(default=None, max_length=1000)


class ShiftIn(BaseModel):
    user_id: int
    area_id: int
    entry_hour: time
    exit_hour: time
    workday: int = Field(ge=0, le=6)  # 0=Dom ... 6=Sab
    valid_from: date | None = None
    valid_until: date | None = None
    is_active: bool = False
    request_id: int | None = None


class AttendanceIn(BaseModel):
    user_id: int
    shift_id: int
    attendance_date: date
    check_in: datetime | None = None
    status: AttendanceStatus | None = None
    notes: str | None = Field(default=None, max_length=1000)
    registered_by: int
    uuid: str = Field(min_length=1, max_length=64)  # generated on the phone; makes offline sync idempotent


class AttendanceUpdate(BaseModel):
    check_in: datetime | None = None
    check_out: datetime | None = None
    status: AttendanceStatus | None = None
    notes: str | None = Field(default=None, max_length=1000)


class HistoryIn(BaseModel):
    user_id: int
    action: str = Field(min_length=1, max_length=100)
    action_date: date
    notes: str | None = Field(default=None, max_length=1000)
    changed_by: int


class HistoryUpdate(BaseModel):
    action: str = Field(min_length=1, max_length=100)
    action_date: date
    notes: str | None = Field(default=None, max_length=1000)
    changed_by: int


# ----------------------------------------------------------------- health
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


# ------------------------------------------------------------------- auth
@app.post("/auth/login", tags=["auth"])
def login(body: LoginIn):
    # TODO: issue a JWT here once the team decides on it.
    return one("authenticate", body.email, body.password, status=401, detail="Credenciales inválidas")


@app.post("/invitations", tags=["auth"], status_code=201)
def create_invitation(body: InvitationIn):
    # The SQL function takes TIMESTAMP (no tz); a tz-aware value would not match its signature.
    exp = body.expires_at
    if exp.tzinfo is not None:
        exp = exp.astimezone(timezone.utc).replace(tzinfo=None)
    return one("generate_invitation_code", body.daycare_id, body.role_id, exp)


@app.post("/invitations/redeem", tags=["auth"])
def redeem_invitation(body: RedeemIn):
    return one("redeem_invitation_code", body.code, status=400, detail="Código inválido o ya usado")


# ---------------------------------------------------------------- catalog
@app.get("/roles/{role_id}", tags=["catalog"])
def get_role(role_id: int):
    return one("get_roles_description", role_id)


@app.get("/positions/{position_id}", tags=["catalog"])
def get_position(position_id: int):
    return one("get_position_description", position_id)


# --------------------------------------------------------------- daycares
@app.get("/daycares/{daycare_id}", tags=["daycares"])
def get_daycare(daycare_id: int):
    return one("get_daycare_by_id", daycare_id)


@app.post("/daycares", tags=["daycares"], status_code=201)
def create_daycare(b: DaycareIn):
    return one("add_daycare", b.name, b.address, b.low_delay, b.medium_delay, b.absence)


@app.put("/daycares/{daycare_id}", tags=["daycares"])
def update_daycare(daycare_id: int, b: DaycareIn):
    return one("modify_daycare", daycare_id, b.name, b.address, b.low_delay, b.medium_delay, b.absence)


@app.get("/daycares/{daycare_id}/personnel", tags=["daycares"])
def daycare_personnel(daycare_id: int):
    return many("get_active_personnel", daycare_id)


@app.get("/daycares/{daycare_id}/areas", tags=["daycares"])
def daycare_areas(daycare_id: int):
    return many("get_daycare_areas", daycare_id)


@app.get("/daycares/{daycare_id}/history", tags=["daycares"])
def daycare_history(daycare_id: int):
    return many("get_daycare_personnel_history", daycare_id)


@app.get("/daycares/{daycare_id}/shifts", tags=["daycares"])
def daycare_shifts_on_day(daycare_id: int, day: date = Query(alias="date")):
    return many("get_users_in_day_by_daycare", daycare_id, day)


@app.get("/daycares/{daycare_id}/shifts/at", tags=["daycares"])
def daycare_shifts_at(daycare_id: int, at: datetime | None = None):
    return many("get_users_in_shift_by_daycare", at or datetime.now(timezone.utc), daycare_id)


@app.get("/daycares/{daycare_id}/attendance", tags=["daycares"])
def daycare_attendance_on_day(daycare_id: int, day: date = Query(alias="date")):
    return many("get_attendance_in_daycare_by_day", daycare_id, day)


@app.get("/daycares/{daycare_id}/attendance/current", tags=["daycares"])
def daycare_attendance_current(daycare_id: int, at: datetime | None = None):
    return many(
        "get_attendance_in_daycare_by_current_shift", daycare_id, at or datetime.now(timezone.utc)
    )


# ------------------------------------------------------------------ areas
@app.get("/areas/{area_id}", tags=["areas"])
def get_area(area_id: int):
    return one("get_area_by_id", area_id)


@app.post("/areas", tags=["areas"], status_code=201)
def create_area(b: AreaCreate):
    return one("add_area", b.daycare_id, b.name, b.minimum_active_staff)


@app.put("/areas/{area_id}", tags=["areas"])
def update_area(area_id: int, b: AreaUpdate):
    return one("modify_area", area_id, b.name, b.minimum_active_staff)


@app.get("/areas/{area_id}/personnel", tags=["areas"])
def area_personnel(area_id: int):
    return many("get_area_personnel", area_id)


# ------------------------------------------------------------------ users
@app.get("/users/{user_id}", tags=["users"])
def get_user(user_id: int):
    return one("get_user_by_id", user_id)


@app.post("/users", tags=["users"], status_code=201)
def create_user(b: UserIn):
    # NOTE: add_user has no password parameter; see how passwords get set.
    return one("add_user", b.daycare_id, b.name, b.lastname, b.email, b.role_id, b.position_id, b.is_active)


@app.put("/users/{user_id}", tags=["users"])
def update_user(user_id: int, b: UserIn):
    return one(
        "modify_user", user_id, b.daycare_id, b.name, b.lastname, b.email,
        b.role_id, b.position_id, b.is_active,
    )


@app.get("/users/{user_id}/shifts", tags=["users"])
def user_shifts(user_id: int):
    return many("get_user_current_shift_days", user_id)


@app.get("/users/{user_id}/attendance", tags=["users"])
def user_attendance(user_id: int):
    return many("get_user_attendances", user_id)


@app.get("/users/{user_id}/requests", tags=["users"])
def user_requests(user_id: int):
    return many("get_user_requests", user_id)


@app.get("/users/{user_id}/history", tags=["users"])
def user_history(user_id: int):
    return many("get_user_history", user_id)


@app.get("/users/{user_id}/status", tags=["users"])
def user_last_status(user_id: int):
    return one("get_last_user_status", user_id)


# --------------------------------------------------------------- requests
@app.get("/requests/{request_id}", tags=["requests"])
def get_request(request_id: int):
    return one("get_request_by_id", request_id)


@app.post("/requests", tags=["requests"], status_code=201)
def create_request(b: RequestIn):
    return one(
        "add_request", b.user_id, b.type, b.status, b.request_date or datetime.now(timezone.utc),
        b.resolved_at, b.resolved_by, b.notes,
    )


# ----------------------------------------------------------------- shifts
@app.get("/shifts/{shift_id}", tags=["shifts"])
def get_shift(shift_id: int):
    return one("get_shift_data_by_id", shift_id)


@app.post("/shifts", tags=["shifts"], status_code=201)
def create_shift(b: ShiftIn):
    return one(
        "add_shift", b.user_id, b.area_id, b.entry_hour, b.exit_hour, b.workday,
        b.valid_from, b.valid_until, b.is_active, b.request_id,
    )


@app.put("/shifts/{shift_id}", tags=["shifts"])
def update_shift(shift_id: int, b: ShiftIn):
    return one(
        "modify_shift", shift_id, b.user_id, b.area_id, b.entry_hour, b.exit_hour, b.workday,
        b.valid_from, b.valid_until, b.is_active, b.request_id,
    )


# ------------------------------------------------------------- attendance
@app.post("/attendance", tags=["attendance"], status_code=201)
def create_attendance(b: AttendanceIn):
    # A repeated `uuid` returns 409: the app should treat that as "already synced".
    return one(
        "add_attendance", b.user_id, b.shift_id, b.attendance_date, b.check_in,
        b.status, b.notes, b.registered_by, b.uuid,
    )


@app.put("/attendance/{attendance_id}", tags=["attendance"])
def update_attendance(attendance_id: int, b: AttendanceUpdate):
    return one("modify_attendance", attendance_id, b.check_in, b.check_out, b.status, b.notes)


# ------------------------------------------------------ personnel history
@app.post("/personnel-history", tags=["history"], status_code=201)
def create_history(b: HistoryIn):
    return one("add_personnel_history", b.user_id, b.action, b.action_date, b.notes, b.changed_by)


@app.get("/personnel-history/{history_id}", tags=["history"])
def get_history(history_id: int):
    return one("get_personnel_history_by_id", history_id)


@app.put("/personnel-history/{history_id}", tags=["history"])
def update_history(history_id: int, b: HistoryUpdate):
    return one(
        "modify_personnel_history", history_id, b.action, b.action_date, b.notes, b.changed_by
    )
