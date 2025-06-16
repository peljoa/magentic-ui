from typing import Any, List, Optional

from fastapi import Depends, HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from slowapi import Limiter
from slowapi.util import get_remote_address

from ..web.config import settings
from .models import User, UserRole
from .msal_service import msal_service

# Rate limiter
limiter = Limiter(key_func=get_remote_address)

# Security scheme
security = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> User:
    """Get current authenticated user from JWT token"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not msal_service:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Authentication service not configured",
        )

    token_data = msal_service.verify_token(credentials.credentials)

    if not token_data.email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: missing email",
        )

    # In production, you'd fetch the user from database
    # For now, we'll create a user object from token data
    user = User(
        email=token_data.email,
        name=token_data.email.split("@")[0],  # Basic name extraction
        roles=[UserRole(role) for role in token_data.roles]
        if token_data.roles
        else [UserRole.USER],
    )

    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user),
) -> User:
    """Get current active user (not suspended)"""
    if current_user.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="User account is not active"
        )
    return current_user


def require_roles(allowed_roles: List[UserRole]):
    """Dependency factory for role-based access control"""

    def role_checker(current_user: User = Depends(get_current_active_user)) -> User:
        if not any(role in current_user.roles for role in allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions"
            )
        return current_user

    return role_checker


# Role-specific dependencies
require_admin = require_roles([UserRole.ADMIN])
require_user_or_admin = require_roles([UserRole.USER, UserRole.ADMIN])


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> Optional[User]:
    """Get current user if authenticated, otherwise return None"""
    if not credentials or not msal_service:
        return None

    try:
        token_data = msal_service.verify_token(credentials.credentials)
        if not token_data.email:
            return None

        return User(
            email=token_data.email,
            name=token_data.email.split("@")[0],
            roles=[UserRole(role) for role in token_data.roles]
            if token_data.roles
            else [UserRole.USER],
        )
    except HTTPException:
        return None


def get_user_id(request: Request) -> str:
    """Extract user ID from request for rate limiting and logging"""
    auth_header = request.headers.get("authorization")
    if auth_header and auth_header.startswith("Bearer ") and msal_service:
        try:
            token = auth_header.split(" ")[1]
            token_data = msal_service.verify_token(token)
            return token_data.user_id or token_data.email or "unknown"
        except Exception:
            pass

    # Fallback to IP address
    return get_remote_address(request)


class SecurityHeaders:
    """Security headers middleware"""

    @staticmethod
    def add_security_headers(response: Response, request: Request) -> Response:
        """Add security headers to response"""
        # HSTS (HTTP Strict Transport Security)
        if settings.HTTPS_ONLY:
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains"
            )

        # XSS Protection
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"

        # Content Security Policy
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
            "style-src 'self' 'unsafe-inline'; "
            "img-src 'self' data: https:; "
            "connect-src 'self' https: wss: ws:; "
            "font-src 'self' data:; "
            "frame-ancestors 'none';"
        )

        # Referrer Policy
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

        return response


def rate_limit_key_func(request: Request) -> str:
    """Custom rate limit key function that considers user"""
    user_id = get_user_id(request)
    return f"{user_id}:{request.url.path}"


# Rate limiting decorators
def standard_rate_limit() -> Any:
    """Standard rate limit: 100 requests per minute"""
    return limiter.limit(
        f"{settings.RATE_LIMIT_REQUESTS}/{settings.RATE_LIMIT_WINDOW}second",
        key_func=rate_limit_key_func
    )


def auth_rate_limit() -> Any:
    """Authentication rate limit: 10 requests per minute"""
    return limiter.limit("10/1minute", key_func=rate_limit_key_func)
