from uuid import UUID

from fastapi import APIRouter, Depends

from db import one
from schemas import HistoryIn, HistoryUpdate
from security import get_current_user

router = APIRouter(
    prefix="/personnel-history", tags=["history"], dependencies=[Depends(get_current_user)]
)


@router.post("", status_code=201)
def create_history(b: HistoryIn):
    return one("add_personnel_history", b.user_id, b.action, b.action_date, b.notes, b.changed_by)


@router.get("/{history_id}")
def get_history(history_id: UUID):
    return one("get_personnel_history_by_id", history_id)


@router.put("/{history_id}")
def update_history(history_id: UUID, b: HistoryUpdate):
    return one(
        "modify_personnel_history", history_id, b.action, b.action_date, b.notes, b.changed_by
    )
