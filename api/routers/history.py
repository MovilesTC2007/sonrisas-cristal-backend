from uuid import UUID

from fastapi import APIRouter, Depends

from db import one
from schemas import HistoryIn, HistoryUpdate
from security import HistoryResource, RequesterDep, UserResource, authorize, get_current_user

router = APIRouter(
    prefix="/personnel-history", tags=["history"], dependencies=[Depends(get_current_user)]
)


def load_history(history_id: UUID) -> HistoryResource:
    return HistoryResource(**one("get_personnel_history_resource", history_id))


@router.post("", status_code=201)
def create_history(b: HistoryIn, requester: RequesterDep):
    target = UserResource(**one("get_user_resource", b.user_id))
    authorize(requester, "create_history", HistoryResource(user_id=b.user_id, daycare_id=target.daycare_id))
    return one("add_personnel_history", b.user_id, b.action, b.action_date, b.notes, b.changed_by)


@router.get("/{history_id}")
def get_history(history_id: UUID, requester: RequesterDep):
    authorize(requester, "get_history", load_history(history_id))
    return one("get_personnel_history_by_id", history_id)


@router.put("/{history_id}")
def update_history(history_id: UUID, b: HistoryUpdate, requester: RequesterDep):
    authorize(requester, "update_history", load_history(history_id))
    return one(
        "modify_personnel_history", history_id, b.action, b.action_date, b.notes, b.changed_by
    )
