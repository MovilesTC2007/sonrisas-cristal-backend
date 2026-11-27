from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException

from db import one
from schemas import ShiftIn
from security import AreaResource, RequesterDep, ShiftResource, UserResource, authorize, get_current_user

router = APIRouter(prefix="/shifts", tags=["shifts"], dependencies=[Depends(get_current_user)])

def load_shift(shift_id: UUID) -> ShiftResource:
    return ShiftResource(**one("get_shift_resource", shift_id))


def _authorize_target(requester, b: ShiftIn) -> None:
    """Checks the *new* user_id/area_id a create or update is pointing at --
    never trust that authorizing against an existing shift's old state is
    enough, since the client can submit a different user_id/area_id."""
    target = UserResource(**one("get_user_resource", b.user_id))
    authorize(requester, "alter_shifts", ShiftResource(user_id=b.user_id, daycare_id=target.daycare_id))
    area = AreaResource(**one("get_area_resource", b.area_id))
    if area.daycare_id != target.daycare_id:
        raise HTTPException(status_code=400, detail="El área no pertenece a la misma estancia que el empleado")


@router.get("/{shift_id}")
def get_shift(shift_id: UUID, requester: RequesterDep):
    authorize(requester, "get_shift", load_shift(shift_id))
    return one("get_shift_data_by_id", shift_id)


@router.post("", status_code=201)
def create_shift(b: ShiftIn, requester: RequesterDep):
    _authorize_target(requester, b)
    return one(
        "add_shift", b.user_id, b.area_id, b.entry_hour, b.exit_hour, b.workday,
        b.valid_from, b.valid_until, b.is_active, b.request_id,
    )


@router.put("/{shift_id}")
def update_shift(shift_id: UUID, b: ShiftIn, requester: RequesterDep):
    authorize(requester, "alter_shifts", load_shift(shift_id))
    _authorize_target(requester, b)
    return one(
        "modify_shift", shift_id, b.user_id, b.area_id, b.entry_hour, b.exit_hour, b.workday,
        b.valid_from, b.valid_until, b.is_active, b.request_id,
    )
