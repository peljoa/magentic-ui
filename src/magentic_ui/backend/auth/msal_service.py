import json
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

import msal
import redis
from fastapi import HTTPException, status
from jose import JWTError, jwt
from loguru import logger

from ..web.config import settings
from .models import Token, TokenData, User


class MSALService:
    """Microsoft Authentication Library service for Azure AD authentication"""

    def __init__(self):
        self.client_id = settings.AZURE_CLIENT_ID
        self.client_secret = settings.AZURE_CLIENT_SECRET
        self.authority = settings.azure_authority_url
        self.redirect_uri = settings.REDIRECT_URI
        self.scopes = settings.SCOPES

        # Initialize Redis for session storage
        try:
            self.redis_client = redis.from_url(
                settings.REDIS_URL, decode_responses=True
            )
        except Exception as e:
            logger.warning(f"Redis connection failed: {e}. Using in-memory storage.")
            self.redis_client = None
            self._memory_store: Dict[str, Any] = {}

        # Only create MSAL app instance if Azure credentials are configured
        self.app = None
        if self.client_id and self.client_secret and settings.AZURE_TENANT_ID:
            try:
                self.app = msal.ConfidentialClientApplication(
                    client_id=self.client_id,
                    client_credential=self.client_secret,
                    authority=self.authority,
                )
                logger.info("MSAL authentication service initialized successfully")
            except Exception as e:
                logger.warning(
                    f"Failed to initialize MSAL service: {e}. Azure AD authentication will be disabled."
                )
                self.app = None
        else:
            logger.info(
                "Azure AD credentials not configured. MSAL authentication service disabled."
            )

    def get_auth_url(self, state: Optional[str] = None) -> tuple[str, str]:
        """Generate Azure AD authentication URL"""
        if not self.app:
            raise HTTPException(
                status_code=status.HTTP_501_NOT_IMPLEMENTED,
                detail="Azure AD authentication is not configured",
            )

        if not state:
            state = secrets.token_urlsafe(32)

        auth_url = self.app.get_authorization_request_url(
            scopes=self.scopes, state=state, redirect_uri=self.redirect_uri
        )

        return auth_url, state

    async def exchange_code_for_token(self, code: str, state: str) -> Dict[str, Any]:
        """Exchange authorization code for access token"""
        if not self.app:
            raise HTTPException(
                status_code=status.HTTP_501_NOT_IMPLEMENTED,
                detail="Azure AD authentication is not configured",
            )

        try:
            result = self.app.acquire_token_by_authorization_code(
                code=code, scopes=self.scopes, redirect_uri=self.redirect_uri
            )

            if "error" in result:
                logger.error(
                    f"MSAL token exchange error: {result.get('error_description')}"
                )
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Authentication failed: {result.get('error_description')}",
                )

            return result

        except Exception as e:
            logger.error(f"Token exchange failed: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="Authentication failed"
            )

    def extract_user_info(self, token_result: Dict[str, Any]) -> User:
        """Extract user information from MSAL token result"""
        id_token_claims = token_result.get("id_token_claims", {})

        email = id_token_claims.get("preferred_username") or id_token_claims.get(
            "email"
        )
        name = id_token_claims.get("name", email)
        object_id = id_token_claims.get("oid")
        tenant_id = id_token_claims.get("tid")

        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Could not extract email from token",
            )

        return User(
            email=email,
            name=name,
            azure_object_id=object_id,
            tenant_id=tenant_id,
            last_login=datetime.now(timezone.utc),
        )

    def create_jwt_token(self, user: User) -> Token:
        """Create JWT token for authenticated user"""
        # Create access token
        access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token_data = {
            "sub": user.email,
            "user_id": user.email,  # Use email as user_id for backward compatibility
            "name": user.name,
            "roles": [role.value for role in user.roles],
            "exp": datetime.now(timezone.utc) + access_token_expires,
            "iat": datetime.now(timezone.utc),
            "type": "access",
        }

        access_token = jwt.encode(
            access_token_data, settings.SECRET_KEY, algorithm=settings.ALGORITHM
        )

        # Create refresh token
        refresh_token_expires = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
        refresh_token_data = {
            "sub": user.email,
            "exp": datetime.now(timezone.utc) + refresh_token_expires,
            "iat": datetime.now(timezone.utc),
            "type": "refresh",
        }

        refresh_token = jwt.encode(
            refresh_token_data, settings.SECRET_KEY, algorithm=settings.ALGORITHM
        )

        return Token(
            access_token=access_token,
            expires_in=int(access_token_expires.total_seconds()),
            refresh_token=refresh_token,
        )

    def verify_token(self, token: str) -> TokenData:
        """Verify JWT token and return token data"""
        try:
            payload = jwt.decode(
                token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
            )

            email: Optional[str] = payload.get("sub")
            user_id: Optional[str] = payload.get("user_id")
            roles: list[str] = payload.get("roles", [])
            token_type: str = payload.get("type", "access")

            if email is None or token_type != "access":
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token",
                    headers={"WWW-Authenticate": "Bearer"},
                )

            return TokenData(email=email, user_id=user_id, roles=roles)

        except JWTError as e:
            logger.error(f"JWT verification failed: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
                headers={"WWW-Authenticate": "Bearer"},
            )

    def refresh_access_token(self, refresh_token: str) -> Token:
        """Refresh access token using refresh token"""
        try:
            payload = jwt.decode(
                refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
            )

            email: Optional[str] = payload.get("sub")
            token_type: str = payload.get("type", "access")

            if email is None or token_type != "refresh":
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid refresh token",
                )

            # Create new access token
            # Note: In production, you'd want to validate the user still exists and is active
            user = User(email=email, name=email.split("@")[0])  # Basic user for refresh
            return self.create_jwt_token(user)

        except JWTError as e:
            logger.error(f"Refresh token verification failed: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token",
            )

    def store_session_data(
        self, session_id: str, data: Dict[str, Any], expire_seconds: int = 3600
    ):
        """Store session data in Redis or memory"""
        try:
            if self.redis_client:
                self.redis_client.setex(
                    f"session:{session_id}",
                    expire_seconds,
                    json.dumps(data, default=str),
                )
            else:
                self._memory_store[f"session:{session_id}"] = {
                    "data": data,
                    "expires": datetime.now(timezone.utc)
                    + timedelta(seconds=expire_seconds),
                }
        except Exception as e:
            logger.error(f"Failed to store session data: {str(e)}")

    def get_session_data(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve session data from Redis or memory"""
        try:
            if self.redis_client:
                data = self.redis_client.get(f"session:{session_id}")
                return json.loads(data) if data else None
            else:
                session_data = self._memory_store.get(f"session:{session_id}")
                if session_data and session_data["expires"] > datetime.now(
                    timezone.utc
                ):
                    return session_data["data"]
                elif session_data:
                    # Expired session
                    del self._memory_store[f"session:{session_id}"]
                return None
        except Exception as e:
            logger.error(f"Failed to retrieve session data: {str(e)}")
            return None

    def delete_session_data(self, session_id: str):
        """Delete session data from Redis or memory"""
        try:
            if self.redis_client:
                self.redis_client.delete(f"session:{session_id}")
            else:
                self._memory_store.pop(f"session:{session_id}", None)
        except Exception as e:
            logger.error(f"Failed to delete session data: {str(e)}")


# Global MSAL service instance
try:
    msal_service = MSALService()
    logger.info("MSAL authentication service initialized successfully")
except Exception as e:
    logger.warning(
        f"Failed to initialize MSAL service: {e}. Azure AD authentication will be disabled."
    )
    msal_service = None
