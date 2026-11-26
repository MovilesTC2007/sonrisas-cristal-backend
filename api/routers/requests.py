from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends

from db import one
from schemas import RequestIn, RequestResolve
from security import RequesterDep, RequestResource, UserResource, authorize, get_current_user

router = APIRouter(prefix="/requests", tags=["requests"], dependencies=[Depends(get_current_user)])

def load_request(request_id: UUID) -> RequestResource:
    return RequestResource(**one("get_request_resource", request_id))

@router.get("/{request_id}")
def get_request(request_id: UUID, requester: RequesterDep):
    authorize(requester, "get_request", load_request(request_id))
    return one("get_request_by_id", request_id)


@router.post("", status_code=201)
def create_request(b: RequestIn, requester: RequesterDep):
    target = UserResource(**one("get_user_resource", b.user_id))
    authorize(requester, "create_request", RequestResource(user_id=b.user_id, daycare_id=target.daycare_id))

    return one(
        "add_request", b.user_id, b.type, "Pending", b.request_date or datetime.now(UTC),
        None, None, b.notes,
    )


@router.put("/{request_id}")
def resolve_request(request_id: UUID, b: RequestResolve, requester: RequesterDep):
    authorize(requester, "resolve_request", load_request(request_id))
    return one(
        "modify_request", request_id, b.status, datetime.now(UTC), requester.id, b.notes,
    )

