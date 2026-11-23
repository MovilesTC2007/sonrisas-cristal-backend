from uuid import UUID

from fastapi import APIRouter, Depends

from db import many, one
from schemas import AreaCreate, AreaUpdate
from security import get_current_user

router = APIRouter(prefix="/areas", tags=["areas"], dependencies=[Depends(get_current_user)])


@router.get("/{area_id}")
def get_area(area_id: UUID):
    return one("get_area_by_id", area_id)


@router.post("", status_code=201)
def create_area(b: AreaCreate):
    return one("add_area", b.daycare_id, b.name, b.minimum_active_staff)


@router.put("/{area_id}")
def update_area(area_id: UUID, b: AreaUpdate):
    return one("modify_area", area_id, b.name, b.minimum_active_staff)


@router.get("/{area_id}/personnel")
def area_personnel(area_id: UUID):
    return many("get_area_personnel", area_id)
