from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends

from db import one
from schemas import RequestIn
from security import get_current_user

router = APIRouter(prefix="/requests", tags=["requests"], dependencies=[Depends(get_current_user)])


@router.get("/{request_id}")
def get_request(request_id: UUID):
    return one("get_request_by_id", request_id)


@router.post("", status_code=201)
def create_request(b: RequestIn):
    return one(
        "add_request", b.user_id, b.type, b.status, b.request_date or datetime.now(timezone.utc),
        b.resolved_at, b.resolved_by, b.notes,
    )
