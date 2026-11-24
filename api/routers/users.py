from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends

from db import many, one
from schemas import UserIn, UserOut
from security import get_current_user

router = APIRouter(prefix="/users", tags=["users"], dependencies=[Depends(get_current_user)])


@router.get("/me", response_model=UserOut)
def get_me(user_id: Annotated[UUID, Depends(get_current_user)]):
    user = one("get_user_by_id", user_id)
    return {**user, "user_id": user_id}


@router.get("/{user_id}")
def get_user(user_id: UUID):
    return one("get_user_by_id", user_id)


@router.put("/{user_id}")
def update_user(user_id: UUID, b: UserIn):
    return one(
        "modify_user", user_id, b.daycare_id, b.name, b.lastname, b.email,
        b.role_id, b.position_id, b.is_active,
    )


@router.get("/{user_id}/shifts")
def user_shifts(user_id: UUID):
    return many("get_user_current_shift_days", user_id)


@router.get("/{user_id}/attendance")
def user_attendance(user_id: UUID):
    return many("get_user_attendances", user_id)


@router.get("/{user_id}/requests")
def user_requests(user_id: UUID):
    return many("get_user_requests", user_id)


@router.get("/{user_id}/history")
def user_history(user_id: UUID):
    return many("get_user_history", user_id)


@router.get("/{user_id}/status")
def user_last_status(user_id: UUID):
    return one("get_last_user_status", user_id)