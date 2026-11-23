from datetime import date, datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from db import many, one
from schemas import DaycareIn
from security import get_current_user

router = APIRouter(prefix="/daycares", tags=["daycares"], dependencies=[Depends(get_current_user)])


@router.get("/{daycare_id}")
def get_daycare(daycare_id: UUID):
    return one("get_daycare_by_id", daycare_id)


@router.post("", status_code=201)
def create_daycare(b: DaycareIn):
    return one("add_daycare", b.name, b.address, b.low_delay, b.medium_delay, b.absence)


@router.put("/{daycare_id}")
def update_daycare(daycare_id: UUID, b: DaycareIn):
    return one("modify_daycare", daycare_id, b.name, b.address, b.low_delay, b.medium_delay, b.absence)


@router.get("/{daycare_id}/personnel")
def daycare_personnel(daycare_id: UUID):
    return many("get_active_personnel", daycare_id)


@router.get("/{daycare_id}/areas")
def daycare_areas(daycare_id: UUID):
    return many("get_daycare_areas", daycare_id)


@router.get("/{daycare_id}/history")
def daycare_history(daycare_id: UUID):
    return many("get_daycare_personnel_history", daycare_id)


@router.get("/{daycare_id}/shifts")
def daycare_shifts_on_day(daycare_id: UUID, day: Annotated[date, Query(alias="date")]):
    return many("get_users_in_day_by_daycare", daycare_id, day)


@router.get("/{daycare_id}/shifts/at")
def daycare_shifts_at(daycare_id: UUID, at: datetime | None = None):
    return many("get_users_in_shift_by_daycare", at or datetime.now(datetime.UTC), daycare_id)


@router.get("/{daycare_id}/attendance")
def daycare_attendance_on_day(daycare_id: UUID, day: Annotated[date, Query(alias="date")]):
    return many("get_attendance_in_daycare_by_day", daycare_id, day)


@router.get("/{daycare_id}/attendance/current")
def daycare_attendance_current(daycare_id: UUID, at: datetime | None = None):
    return many(
        "get_attendance_in_daycare_by_current_shift", daycare_id, at or datetime.now(datetime.UTC)
    )
