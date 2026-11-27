"""Regression tests for api/policy.polar.

These exercise the Oso policy directly (oso.is_allowed), with no FastAPI
client and no database: each test is a single ABAC decision, so running
them is fast enough to run on every change to policy.polar. They encode
the business rules from the security review, not implementation details,
so they should keep passing across future refactors of the routers.
"""

import uuid

from security import (
    AreaResource,
    AttendanceResource,
    DaycareResource,
    HistoryResource,
    InvitationCodeResource,
    Requester,
    RequestResource,
    ShiftResource,
    UserResource,
    oso,
)

DAYCARE_A = uuid.uuid4()
DAYCARE_B = uuid.uuid4()


def requester(role: str, daycare_id: uuid.UUID = DAYCARE_A) -> Requester:
    return Requester(id=uuid.uuid4(), role=role, daycare_id=daycare_id)


def allowed(req: Requester, action: str, resource: object) -> bool:
    return oso.is_allowed(req, action, resource)

def test_staff_cannot_update_own_role():
    staff = requester("staff")
    own_record = UserResource(user_id=staff.id, daycare_id=DAYCARE_A, role="staff")
    assert not allowed(staff, "update_user_role", own_record)


def test_encargado_cannot_update_roles():
    encargado = requester("encargado")
    target = UserResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A, role="staff")
    assert not allowed(encargado, "update_user_role", target)


def test_director_can_update_role():
    director = requester("director")
    target = UserResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A, role="staff")
    assert allowed(director, "update_user_role", target)


# --- invitations: encargado -> staff only; director -> encargado only ---


def test_encargado_can_invite_staff_in_own_daycare():
    encargado = requester("encargado")
    invite = InvitationCodeResource(daycare_id=DAYCARE_A, role="staff")
    assert allowed(encargado, "create_invitation", invite)


def test_encargado_cannot_invite_another_encargado():
    encargado = requester("encargado")
    invite = InvitationCodeResource(daycare_id=DAYCARE_A, role="encargado")
    assert not allowed(encargado, "create_invitation", invite)


def test_encargado_cannot_invite_outside_own_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    invite = InvitationCodeResource(daycare_id=DAYCARE_B, role="staff")
    assert not allowed(encargado, "create_invitation", invite)


def test_director_can_invite_encargado():
    director = requester("director")
    invite = InvitationCodeResource(daycare_id=DAYCARE_A, role="encargado")
    assert allowed(director, "create_invitation", invite)


def test_director_cannot_invite_staff_directly():
    director = requester("director")
    invite = InvitationCodeResource(daycare_id=DAYCARE_A, role="staff")
    assert not allowed(director, "create_invitation", invite)


# --- requests: staff creates for themself, cannot resolve their own ---


def test_staff_can_create_own_request():
    staff = requester("staff")
    assert allowed(staff, "create_request", RequestResource(user_id=staff.id, daycare_id=DAYCARE_A))


def test_staff_cannot_resolve_own_request():
    staff = requester("staff")
    own_request = RequestResource(user_id=staff.id, daycare_id=DAYCARE_A)
    assert not allowed(staff, "resolve_request", own_request)


def test_encargado_can_resolve_request_in_own_daycare():
    encargado = requester("encargado")
    assert allowed(encargado, "resolve_request", RequestResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A))


def test_encargado_cannot_resolve_request_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    assert not allowed(encargado, "resolve_request", RequestResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B))


# --- personnel history: the subject may never author their own record ---


def test_staff_cannot_create_own_history():
    staff = requester("staff")
    assert not allowed(staff, "create_history", HistoryResource(user_id=staff.id, daycare_id=DAYCARE_A))


def test_encargado_can_create_history_for_staff():
    encargado = requester("encargado")
    record = HistoryResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    assert allowed(encargado, "create_history", record)


# --- daycare creation is director-only ---


def test_encargado_cannot_create_daycare():
    encargado = requester("encargado")
    assert not allowed(encargado, "create_daycare", encargado)


def test_director_can_create_daycare():
    director = requester("director")
    assert allowed(director, "create_daycare", director)


# --- director-only aggregate reads stay out of reach for staff ---


def test_staff_cannot_read_daycare_information():
    staff = requester("staff")
    assert not allowed(staff, "get_daycare_information", DaycareResource(daycare_id=DAYCARE_A))

# --- users: get_user / update_user cross-daycare and cross-person BOLA ---


def test_encargado_cannot_view_user_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    other = UserResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B, role="staff")
    assert not allowed(encargado, "get_user", other)


def test_staff_cannot_view_another_users_profile():
    staff = requester("staff")
    other = UserResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A, role="staff")
    assert not allowed(staff, "get_user", other)


def test_director_can_view_any_user():
    director = requester("director", daycare_id=DAYCARE_A)
    other = UserResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B, role="staff")
    assert allowed(director, "get_user", other)


def test_encargado_cannot_update_user_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    other = UserResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B, role="staff")
    assert not allowed(encargado, "update_user", other)


def test_staff_cannot_update_another_users_profile():
    staff = requester("staff")
    other = UserResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A, role="staff")
    assert not allowed(staff, "update_user", other)


def test_staff_can_update_own_profile():
    staff = requester("staff")
    own_record = UserResource(user_id=staff.id, daycare_id=DAYCARE_A, role="staff")
    assert allowed(staff, "update_user", own_record)


# --- daycare: get_daycare / update_daycare / get_daycare_information ---


def test_member_can_view_own_daycare():
    for role in ("staff", "encargado", "director"):
        member = requester(role, daycare_id=DAYCARE_A)
        assert allowed(member, "get_daycare", DaycareResource(daycare_id=DAYCARE_A))


def test_director_can_view_any_daycare_basic_info():
    director = requester("director", daycare_id=DAYCARE_A)
    assert allowed(director, "get_daycare", DaycareResource(daycare_id=DAYCARE_B))


def test_encargado_cannot_view_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    assert not allowed(encargado, "get_daycare", DaycareResource(daycare_id=DAYCARE_B))


def test_encargado_can_update_own_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    assert allowed(encargado, "update_daycare", DaycareResource(daycare_id=DAYCARE_A))


def test_encargado_cannot_update_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    assert not allowed(encargado, "update_daycare", DaycareResource(daycare_id=DAYCARE_B))


def test_staff_cannot_update_daycare():
    staff = requester("staff", daycare_id=DAYCARE_A)
    assert not allowed(staff, "update_daycare", DaycareResource(daycare_id=DAYCARE_A))


def test_director_cannot_update_daycare():
    # Matches the stated business rule: director is read-only (plus
    # creating new daycares/encargados), never an editor of daycare data.
    director = requester("director", daycare_id=DAYCARE_A)
    assert not allowed(director, "update_daycare", DaycareResource(daycare_id=DAYCARE_A))


def test_encargado_cannot_read_daycare_information_of_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    assert not allowed(encargado, "get_daycare_information", DaycareResource(daycare_id=DAYCARE_B))


def test_director_can_read_any_daycare_information():
    director = requester("director", daycare_id=DAYCARE_A)
    assert allowed(director, "get_daycare_information", DaycareResource(daycare_id=DAYCARE_B))


# --- areas: get_area / alter_areas / get_area_information ---


def test_staff_can_view_area_in_own_daycare():
    staff = requester("staff", daycare_id=DAYCARE_A)
    assert allowed(staff, "get_area", AreaResource(daycare_id=DAYCARE_A))


def test_staff_cannot_view_area_in_other_daycare():
    staff = requester("staff", daycare_id=DAYCARE_A)
    assert not allowed(staff, "get_area", AreaResource(daycare_id=DAYCARE_B))


def test_director_can_view_any_area():
    director = requester("director", daycare_id=DAYCARE_A)
    assert allowed(director, "get_area", AreaResource(daycare_id=DAYCARE_B))


def test_encargado_can_alter_areas_in_own_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    assert allowed(encargado, "alter_areas", AreaResource(daycare_id=DAYCARE_A))


def test_encargado_cannot_alter_areas_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    assert not allowed(encargado, "alter_areas", AreaResource(daycare_id=DAYCARE_B))


def test_staff_cannot_alter_areas():
    staff = requester("staff", daycare_id=DAYCARE_A)
    assert not allowed(staff, "alter_areas", AreaResource(daycare_id=DAYCARE_A))


def test_director_cannot_alter_areas():
    director = requester("director", daycare_id=DAYCARE_A)
    assert not allowed(director, "alter_areas", AreaResource(daycare_id=DAYCARE_A))


def test_staff_cannot_read_area_information():
    staff = requester("staff", daycare_id=DAYCARE_A)
    assert not allowed(staff, "get_area_information", AreaResource(daycare_id=DAYCARE_A))


def test_encargado_cannot_read_area_information_of_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    assert not allowed(encargado, "get_area_information", AreaResource(daycare_id=DAYCARE_B))


def test_director_can_read_any_area_information():
    director = requester("director", daycare_id=DAYCARE_A)
    assert allowed(director, "get_area_information", AreaResource(daycare_id=DAYCARE_B))


# --- requests: get_request cross-daycare / cross-person BOLA ---


def test_staff_cannot_view_another_staff_members_request():
    staff = requester("staff", daycare_id=DAYCARE_A)
    other_request = RequestResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    assert not allowed(staff, "get_request", other_request)


def test_encargado_cannot_view_request_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    other_request = RequestResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert not allowed(encargado, "get_request", other_request)


def test_director_can_view_any_request():
    director = requester("director", daycare_id=DAYCARE_A)
    other_request = RequestResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert allowed(director, "get_request", other_request)


def test_staff_cannot_create_request_for_another_user():
    # The BOLA this guards against: a staff member crafting a request body
    # with someone else's user_id to file it "as" that person.
    staff = requester("staff", daycare_id=DAYCARE_A)
    other_users_request = RequestResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    assert not allowed(staff, "create_request", other_users_request)


def test_encargado_cannot_create_request_for_staff():
    # create_request is staff-only (on their own behalf); an encargado
    # filing a request "as" one of their staff is not a modeled action.
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    assert not allowed(
        encargado, "create_request", RequestResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    )


# --- shifts: get_shift / alter_shifts ---


def test_staff_can_view_own_shift():
    staff = requester("staff", daycare_id=DAYCARE_A)
    own_shift = ShiftResource(user_id=staff.id, daycare_id=DAYCARE_A)
    assert allowed(staff, "get_shift", own_shift)


def test_staff_cannot_view_another_employees_shift():
    staff = requester("staff", daycare_id=DAYCARE_A)
    other_shift = ShiftResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    assert not allowed(staff, "get_shift", other_shift)


def test_encargado_cannot_view_shift_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    other_shift = ShiftResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert not allowed(encargado, "get_shift", other_shift)


def test_director_can_view_any_shift():
    director = requester("director", daycare_id=DAYCARE_A)
    other_shift = ShiftResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert allowed(director, "get_shift", other_shift)


def test_encargado_can_alter_shifts_in_own_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    shift = ShiftResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    assert allowed(encargado, "alter_shifts", shift)


def test_encargado_cannot_alter_shifts_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    shift = ShiftResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert not allowed(encargado, "alter_shifts", shift)


def test_staff_cannot_alter_own_shift():
    # Staff can see their shift but never edit it -- only the encargado
    # schedules shifts.
    staff = requester("staff", daycare_id=DAYCARE_A)
    own_shift = ShiftResource(user_id=staff.id, daycare_id=DAYCARE_A)
    assert not allowed(staff, "alter_shifts", own_shift)


# --- attendance: create_attendance (self check-in) / update_attendance ---


def test_staff_can_create_own_attendance():
    staff = requester("staff", daycare_id=DAYCARE_A)
    own_attendance = AttendanceResource(user_id=staff.id, daycare_id=DAYCARE_A)
    assert allowed(staff, "create_attendance", own_attendance)


def test_staff_cannot_create_attendance_for_another_employee():
    # The BOLA this guards against: checking someone else in/out by
    # supplying their user_id instead of your own.
    staff = requester("staff", daycare_id=DAYCARE_A)
    other_attendance = AttendanceResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    assert not allowed(staff, "create_attendance", other_attendance)


def test_encargado_can_create_attendance_for_staff_in_own_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    attendance = AttendanceResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    assert allowed(encargado, "create_attendance", attendance)


def test_encargado_cannot_create_attendance_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    attendance = AttendanceResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert not allowed(encargado, "create_attendance", attendance)


def test_staff_cannot_update_own_attendance():
    # Tamper-prevention: staff can punch in but never rewrite the record
    # afterwards (e.g. to erase a "Late"/"Absent" status).
    staff = requester("staff", daycare_id=DAYCARE_A)
    own_attendance = AttendanceResource(user_id=staff.id, daycare_id=DAYCARE_A)
    assert not allowed(staff, "update_attendance", own_attendance)


def test_encargado_can_update_attendance_in_own_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    attendance = AttendanceResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    assert allowed(encargado, "update_attendance", attendance)


def test_encargado_cannot_update_attendance_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    attendance = AttendanceResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert not allowed(encargado, "update_attendance", attendance)


# --- personnel history: get_history / update_history BOLA ---


def test_staff_can_view_own_history():
    staff = requester("staff", daycare_id=DAYCARE_A)
    own_record = HistoryResource(user_id=staff.id, daycare_id=DAYCARE_A)
    assert allowed(staff, "get_history", own_record)


def test_staff_cannot_view_another_employees_history():
    staff = requester("staff", daycare_id=DAYCARE_A)
    other_record = HistoryResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    assert not allowed(staff, "get_history", other_record)


def test_encargado_cannot_view_history_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    other_record = HistoryResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert not allowed(encargado, "get_history", other_record)


def test_director_can_view_any_history():
    director = requester("director", daycare_id=DAYCARE_A)
    other_record = HistoryResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert allowed(director, "get_history", other_record)


def test_encargado_can_create_history_in_own_daycare_only():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    record = HistoryResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert not allowed(encargado, "create_history", record)


def test_encargado_can_update_history_in_own_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    record = HistoryResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_A)
    assert allowed(encargado, "update_history", record)


def test_encargado_cannot_update_history_in_other_daycare():
    encargado = requester("encargado", daycare_id=DAYCARE_A)
    record = HistoryResource(user_id=uuid.uuid4(), daycare_id=DAYCARE_B)
    assert not allowed(encargado, "update_history", record)


def test_staff_cannot_update_history_even_their_own():
    staff = requester("staff", daycare_id=DAYCARE_A)
    own_record = HistoryResource(user_id=staff.id, daycare_id=DAYCARE_A)
    assert not allowed(staff, "update_history", own_record)
