from uuid import UUID

from fastapi import APIRouter, Depends

from db import one
from security import get_current_user

router = APIRouter(tags=["catalog"], dependencies=[Depends(get_current_user)])


@router.get("/roles/{role_id}")
def get_role(role_id: UUID):
    return one("get_roles_description", role_id)


@router.get("/positions/{position_id}")
def get_position(position_id: UUID):
    return one("get_position_description", position_id)
