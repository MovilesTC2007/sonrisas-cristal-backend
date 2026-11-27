from datetime import UTC, datetime, timedelta
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends

from db import one
from schemas import InvitationIn, LoginIn, LoginOut, RedeemIn
from security import (
    InvitationCodeResource,
    RequesterDep,
    authorize,
    create_access_token,
    get_current_user,
    oauth2_scheme,
    revoke_token,
)

# Login and invitation redemption have to work without a token
router = APIRouter(prefix="/auth", tags=["auth"])

INVITATION_VALIDITY = timedelta(days=3)


@router.post("/login", response_model=LoginOut)
def login(body: LoginIn):
    user_id = one("authenticate", body.email, body.password, status=401, detail="Credenciales inválidas")["authenticate"]
    user = one("get_user_by_id", user_id)
    token = create_access_token({"sub": str(user_id)})
    return LoginOut(access_token=token, user={**user, "user_id": user_id})


@router.post("/logout", status_code=204)
def logout(
    token: Annotated[str, Depends(oauth2_scheme)],
    _user: Annotated[UUID, Depends(get_current_user)],
) -> None:
    # get_current_user already rejected invalid, expired or already-logged-out tokens.
    revoke_token(token)


invitations_router = APIRouter(prefix="/invitations", tags=["auth"])


@invitations_router.post("", status_code=201, dependencies=[Depends(get_current_user)])
def create_invitation(body: InvitationIn, requester: RequesterDep):
    role = one("get_roles_description", body.role_id, status=400, detail="Rol inválido")["get_roles_description"]
    authorize(requester, "create_invitation", InvitationCodeResource(daycare_id=body.daycare_id, role=role))
    expires_at = datetime.now(UTC).replace(tzinfo=None) + INVITATION_VALIDITY
    return one(
        "generate_invitation_code",
        body.daycare_id, body.role_id, body.position_id,
        body.name, body.lastname, body.is_active, expires_at,
    )

@invitations_router.post("/redeem")
def redeem_invitation(body: RedeemIn):
    return one("redeem_invitation_code", body.code, status=400, detail="Código inválido o ya usado")
