from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from enum import Enum


class UserRole(str, Enum):
    ADMIN = "admin"
    USER = "user"
    GUEST = "guest"


class UserStatus(str, Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"


class User(BaseModel):
    id: Optional[str] = None
    email: EmailStr
    name: str
    roles: List[UserRole] = [UserRole.USER]
    status: UserStatus = UserStatus.ACTIVE
    created_at: Optional[datetime] = None
    last_login: Optional[datetime] = None
    avatar_url: Optional[str] = None

    # Azure AD specific fields
    azure_object_id: Optional[str] = None
    tenant_id: Optional[str] = None


class UserCreate(BaseModel):
    email: EmailStr
    name: str
    roles: List[UserRole] = [UserRole.USER]


class UserUpdate(BaseModel):
    name: Optional[str] = None
    roles: Optional[List[UserRole]] = None
    status: Optional[UserStatus] = None


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    refresh_token: Optional[str] = None


class TokenData(BaseModel):
    email: Optional[str] = None
    user_id: Optional[str] = None
    roles: List[str] = []


class MSALAuthResponse(BaseModel):
    code: str
    state: Optional[str] = None
    session_state: Optional[str] = None


class LoginRequest(BaseModel):
    redirect_url: Optional[str] = None


class LoginResponse(BaseModel):
    auth_url: str
    state: str
