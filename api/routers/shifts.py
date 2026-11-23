from uuid import UUID

from fastapi import APIRouter, Depends

from db import one
from schemas import ShiftIn
from security import get_current_user

router = APIRouter(prefix="/shifts", tags=["shifts"], dependencies=[Depends(get_current_user)])


@router.get("/{shift_id}")
def get_shift(shift_id: UUID):
    return one("get_shift_data_by_id", shift_id)


@router.post("", status_code=201)
def create_shift(b: ShiftIn):
    return one(
        "add_shift", b.user_id, b.area_id, b.entry_hour, b.exit_hour, b.workday,
        b.valid_from, b.valid_until, b.is_active, b.request_id,
    )


@router.put("/{shift_id}")
def update_shift(shift_id: UUID, b: ShiftIn):
    return one(
        "modify_shift", shift_id, b.user_id, b.area_id, b.entry_hour, b.exit_hour, b.workday,
        b.valid_from, b.valid_until, b.is_active, b.request_id,
    )
