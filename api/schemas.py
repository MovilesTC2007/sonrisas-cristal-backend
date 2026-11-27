from datetime import date, datetime, time
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field

RequestType = Literal["Vacation", "Sick Leave", "Personal Leave"]
RequestStatus = Literal["Pending", "Approved", "Rejected"]
RequestResolution = Literal["Approved", "Rejected"]
AttendanceStatus = Literal["Attended", "Late", "Absent", "Left Early"]


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class LoginIn(BaseModel):
    email: str = Field(max_length=99)
    password: str = Field(min_length=1, max_length=200)


class UserOut(BaseModel):
    user_id: UUID
    daycare_id: UUID
    name: str
    lastname: str
    email: str
    role_id: UUID | None = None
    position_id: UUID | None = None
    is_active: bool
    updated_at: datetime


class LoginOut(Token):
    user: UserOut


class RedeemIn(BaseModel):
    code: str = Field(min_length=1, max_length=6)
    email: str = Field(max_length=99)
    password: str = Field(min_length=1, max_length=200)


class InvitationIn(BaseModel):
    daycare_id: UUID
    role_id: UUID
    position_id: UUID | None = None
    name: str = Field(min_length=1, max_length=100)
    lastname: str = Field(min_length=1, max_length=100)
    is_active: bool = False


class UserProfileUpdate(BaseModel):
    """Self/encargado-editable fields. role_id and daycare_id are deliberately
    excluded: changing them is privilege-sensitive and goes through
    `UserRoleUpdate` (director-only) instead."""

    name: str = Field(min_length=1, max_length=100)
    lastname: str = Field(min_length=1, max_length=100)
    email: str = Field(max_length=99)
    position_id: UUID | None = None
    is_active: bool = False


class UserRoleUpdate(BaseModel):
    role_id: UUID
    daycare_id: UUID | None = None


class DaycareIn(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    address: str = Field(min_length=1, max_length=300)
    low_delay: int = Field(ge=0)
    medium_delay: int = Field(ge=0)
    absence: int = Field(ge=0)


class AreaCreate(BaseModel):
    daycare_id: UUID
    name: str = Field(min_length=1, max_length=100)
    minimum_active_staff: int = Field(ge=0)


class AreaUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    minimum_active_staff: int = Field(ge=0)


class RequestIn(BaseModel):
    """status/resolved_at/resolved_by are deliberately absent: a request is
    always created as Pending and resolved only through `RequestResolve`, by
    someone with authority over it, never by the requester at creation time."""

    user_id: UUID
    type: RequestType
    request_date: datetime | None = None
    notes: str | None = Field(default=None, max_length=1000)


class RequestResolve(BaseModel):
    status: RequestResolution
    notes: str | None = Field(default=None, max_length=1000)


class ShiftIn(BaseModel):
    user_id: UUID
    area_id: UUID
    entry_hour: time
    exit_hour: time
    workday: int = Field(ge=0, le=6)  # 0=Dom ... 6=Sab
    valid_from: date | None = None
    valid_until: date | None = None
    is_active: bool = False
    request_id: UUID | None = None


class AttendanceIn(BaseModel):
    """registered_by is deliberately absent: it is always the authenticated
    requester, never a client-supplied id (otherwise anyone could forge
    another user's name into the audit trail)."""

    user_id: UUID
    shift_id: UUID
    attendance_date: date
    check_in: datetime | None = None
    status: AttendanceStatus | None = None
    notes: str | None = Field(default=None, max_length=1000)
    uuid: str = Field(min_length=1, max_length=64)  # generated on the phone; makes offline sync idempotent


class AttendanceUpdate(BaseModel):
    check_in: datetime | None = None
    check_out: datetime | None = None
    status: AttendanceStatus | None = None
    notes: str | None = Field(default=None, max_length=1000)


class HistoryIn(BaseModel):
    """changed_by is deliberately absent: it is always the authenticated
    requester, never a client-supplied id (otherwise staff could forge who
    is credited with an HR record)."""

    user_id: UUID
    action: str = Field(min_length=1, max_length=100)
    action_date: date
    notes: str | None = Field(default=None, max_length=1000)


class HistoryUpdate(BaseModel):
    action: str = Field(min_length=1, max_length=100)
    action_date: date
    notes: str | None = Field(default=None, max_length=1000)
