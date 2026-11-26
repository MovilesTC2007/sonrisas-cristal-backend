from uuid import UUID

from fastapi import APIRouter, Depends

from db import one
from schemas import AttendanceIn, AttendanceUpdate
from security import AttendanceResource, RequesterDep, UserResource, authorize, get_current_user

router = APIRouter(prefix="/attendance", tags=["attendance"], dependencies=[Depends(get_current_user)])

def load_attendance(attendance_id: UUID) -> AttendanceResource:
    return AttendanceResource(**one("get_attendance_resource", attendance_id))


@router.post("", status_code=201)
def create_attendance(b: AttendanceIn, requester: RequesterDep):
    target = UserResource(**one("get_user_resource", b.user_id))
    authorize(requester, "create_attendance", AttendanceResource(user_id=b.user_id, daycare_id=target.daycare_id))
    # A repeated `uuid` returns 409: the app should treat that as "already synced".
    return one(
        "add_attendance", b.user_id, b.shift_id, b.attendance_date, b.check_in,
        b.status, b.notes, requester.id, b.uuid,
    )


@router.put("/{attendance_id}")
def update_attendance(attendance_id: UUID, b: AttendanceUpdate, requester: RequesterDep):
    authorize(requester, "update_attendance", load_attendance(attendance_id))
    return one("modify_attendance", attendance_id, b.check_in, b.check_out, b.status, b.notes)
