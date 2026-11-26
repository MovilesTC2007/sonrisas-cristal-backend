"""Regression tests for api/policy.polar.

These exercise the Oso policy directly (oso.is_allowed), with no FastAPI
client and no database: each test is a single ABAC decision, so running
them is fast enough to run on every change to policy.polar. They encode
the business rules from the security review, not implementation details,
so they should keep passing across future refactors of the routers.
"""

import uuid

from security import (
    DaycareResource,
    HistoryResource,
    InvitationCodeResource,
    Requester,
    RequestResource,
    UserResource,
    oso,
)

DAYCARE_A = uuid.uuid4()
DAYCARE_B = uuid.uuid4()


def requester(role: str, daycare_id: uuid.UUID = DAYCARE_A) -> Requester:
    return Requester(id=uuid.uuid4(), role=role, daycare_id=daycare_id)


def allowed(req: Requester, action: str, resource: object) -> bool:
    return oso.is_allowed(req, action, resource)


# --- the bug this suite exists to catch: staff could promote themselves ---


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
