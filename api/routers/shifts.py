from uuid import UUID

from fastapi import APIRouter, Depends

from db import one
from schemas import ShiftIn
from security import RequesterDep, ShiftResource, UserResource, authorize, get_current_user

router = APIRouter(prefix="/shifts", tags=["shifts"], dependencies=[Depends(get_current_user)])

def load_shift(shift_id: UUID) -> ShiftResource:
    return ShiftResource(**one("get_shift_resource", shift_id))


@router.get("/{shift_id}")
def get_shift(shift_id: UUID, requester: RequesterDep):
    authorize(requester, "get_shift", load_shift(shift_id))
    return one("get_shift_data_by_id", shift_id)


@router.post("", status_code=201)
def create_shift(b: ShiftIn, requester: RequesterDep):
    target = UserResource(**one("get_user_resource", b.user_id))
    authorize(requester, "alter_shifts", ShiftResource(user_id=b.user_id, daycare_id=target.daycare_id))
    return one(
        "add_shift", b.user_id, b.area_id, b.entry_hour, b.exit_hour, b.workday,
        b.valid_from, b.valid_until, b.is_active, b.request_id,
    )


@router.put("/{shift_id}")
def update_shift(shift_id: UUID, b: ShiftIn, requester: RequesterDep):
    authorize(requester, "alter_shifts", load_shift(shift_id))
    return one(
        "modify_shift", shift_id, b.user_id, b.area_id, b.entry_hour, b.exit_hour, b.workday,
        b.valid_from, b.valid_until, b.is_active, b.request_id,
    )
