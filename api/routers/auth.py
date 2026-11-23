from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends

from db import one
from schemas import InvitationIn, LoginIn, RedeemIn, Token
from security import create_access_token, get_current_user

# Login and invitation redemption have to work without a token
router = APIRouter(prefix="/auth", tags=["auth"])

INVITATION_VALIDITY = timedelta(days=3)


@router.post("/login", response_model=Token)
def login(body: LoginIn):
    user = one("authenticate", body.email, body.password, status=401, detail="Credenciales inválidas")
    token = create_access_token({"sub": str(user["authenticate"])})
    return Token(access_token=token)


invitations_router = APIRouter(prefix="/invitations", tags=["auth"])


@invitations_router.post("", status_code=201, dependencies=[Depends(get_current_user)])
def create_invitation(body: InvitationIn):
    expires_at = datetime.now(UTC).replace(tzinfo=None) + INVITATION_VALIDITY
    return one("generate_invitation_code", body.daycare_id, body.role_id, expires_at)


@invitations_router.post("/redeem")
def redeem_invitation(body: RedeemIn):
    return one("redeem_invitation_code", body.code, status=400, detail="Código inválido o ya usado")
