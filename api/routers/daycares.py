from datetime import UTC, date, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from db import many, one
from schemas import DaycareIn
from security import DaycareResource, RequesterDep, authorize, get_current_user

router = APIRouter(prefix="/daycares", tags=["daycares"], dependencies=[Depends(get_current_user)])


def load_daycare(daycare_id: UUID) -> DaycareResource:
    return DaycareResource(**one("get_daycare_resource", daycare_id))


@router.get("/{daycare_id}")
def get_daycare(daycare_id: UUID, requester: RequesterDep):
    authorize(requester, "get_daycare", load_daycare(daycare_id))
    return one("get_daycare_by_id", daycare_id)


@router.post("", status_code=201)
def create_daycare(b: DaycareIn, requester: RequesterDep):
    authorize(requester, "create_daycare", requester)
    return one("add_daycare", b.name, b.address, b.low_delay, b.medium_delay, b.absence)


@router.put("/{daycare_id}")
def update_daycare(daycare_id: UUID, b: DaycareIn, requester: RequesterDep):
    authorize(requester, "update_daycare", load_daycare(daycare_id))
    return one("modify_daycare", daycare_id, b.name, b.address, b.low_delay, b.medium_delay, b.absence)


@router.get("/{daycare_id}/personnel")
def daycare_personnel(daycare_id: UUID, requester: RequesterDep):
    authorize(requester, "get_daycare_information", load_daycare(daycare_id))
    return many("get_active_personnel", daycare_id)


@router.get("/{daycare_id}/areas")
def daycare_areas(daycare_id: UUID, requester: RequesterDep):
    authorize(requester, "get_daycare_information", load_daycare(daycare_id))
    return many("get_daycare_areas", daycare_id)


@router.get("/{daycare_id}/history")
def daycare_history(daycare_id: UUID, requester: RequesterDep):
    authorize(requester, "get_daycare_information", load_daycare(daycare_id))
    return many("get_daycare_personnel_history", daycare_id)


@router.get("/{daycare_id}/shifts")
def daycare_shifts_on_day(daycare_id: UUID, day: Annotated[date, Query(alias="date")], requester: RequesterDep):
    authorize(requester, "get_daycare_information", load_daycare(daycare_id))
    return many("get_users_in_day_by_daycare", daycare_id, day)


@router.get("/{daycare_id}/shifts/at")
def daycare_shifts_at(daycare_id: UUID, requester: RequesterDep, at: datetime | None = None):
    authorize(requester, "get_daycare_information", load_daycare(daycare_id))
    return many("get_users_in_shift_by_daycare", at or datetime.now(UTC), daycare_id)


@router.get("/{daycare_id}/attendance")
def daycare_attendance_on_day(daycare_id: UUID, day: Annotated[date, Query(alias="date")], requester: RequesterDep):
    authorize(requester, "get_daycare_information", load_daycare(daycare_id))
    return many("get_attendance_in_daycare_by_day", daycare_id, day)


@router.get("/{daycare_id}/attendance/current")
def daycare_attendance_current(daycare_id: UUID, requester: RequesterDep, at: datetime | None = None):
    authorize(requester, "get_daycare_information", load_daycare(daycare_id))
    return many(
        "get_attendance_in_daycare_by_current_shift", daycare_id, at or datetime.now(UTC)
    )