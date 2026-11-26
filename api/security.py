import os
from datetime import UTC, datetime, timedelta
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from oso import Oso
from pydantic import BaseModel

from db import one

SECRET_KEY = os.environ.get("SECRET_KEY")
ALGORITHM = os.environ.get("ALGORITHM")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES"))

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# Password hashing/verification is done in Postgres (pgcrypto + pepper, see
# functions.sql `authenticate`/`add_user`) — this file never sees a raw hash.

# oso initialization
class Requester(BaseModel):
    id: UUID
    daycare_id: UUID
    role: str

class UserResource(BaseModel):
    user_id: UUID
    daycare_id: UUID
    role: str

class DaycareResource(BaseModel):
    daycare_id: UUID

class AreaResource(BaseModel):
    daycare_id: UUID

class InvitationCodeResource(BaseModel):
    daycare_id: UUID
    role: str  # target role description (e.g. "staff", "encargado"), not the role_id

class RequestResource(BaseModel):
    user_id: UUID
    daycare_id: UUID

class ShiftResource(BaseModel):
    user_id: UUID
    daycare_id: UUID

class AttendanceResource(BaseModel):
    user_id: UUID
    daycare_id: UUID

class HistoryResource(BaseModel):
    user_id: UUID
    daycare_id: UUID


# Oso engine initialization
oso = Oso()
oso.register_class(Requester)
oso.register_class(UserResource)
oso.register_class(DaycareResource)
oso.register_class(AreaResource)
oso.register_class(InvitationCodeResource)
oso.register_class(RequestResource)
oso.register_class(ShiftResource)
oso.register_class(AttendanceResource)
oso.register_class(HistoryResource)
oso.load_files(["policy.polar"])


def authorize(requester: Requester, action: str, resource: object) -> None:
    # is_allowed() (not authorize()) because this policy has no "read" rule
    # for Oso to fall back on when deciding 403 vs 404; a plain boolean check
    # avoids depending on that undefined fallback.
    if not oso.is_allowed(requester, action, resource):
        raise HTTPException(status_code=403, detail="No autorizado")

def create_access_token(data: dict, expires_minutes: int = ACCESS_TOKEN_EXPIRE_MINUTES) -> str:
    to_encode = data.copy()
    expire = datetime.now(UTC) + timedelta(minutes=expires_minutes)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(token: str = Depends(oauth2_scheme)) -> UUID:
    credentials_error = HTTPException(
        status_code=401,
        detail="No autorizado",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
    except JWTError as e:
        raise credentials_error from e
    if user_id is None:
        raise credentials_error
    try:
        return UUID(user_id)
    except ValueError as e:
        raise credentials_error from e


def get_current_requester(user_id: Annotated[UUID, Depends(get_current_user)]) -> Requester:
    row = one("get_user_resource", user_id, status=401, detail="No autorizado")
    return Requester(id=row["user_id"], role=row["role"], daycare_id=row["daycare_id"])

RequesterDep = Annotated[Requester, Depends(get_current_requester)]
