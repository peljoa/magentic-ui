from fastapi import APIRouter, Depends, HTTPException, status, Request, Response
from fastapi.responses import RedirectResponse
from loguru import logger
import secrets
from typing import Any

from .msal_service import msal_service
from .models import (
    LoginRequest,
    LoginResponse,
    Token,
    User,
    UserCreate,
    UserUpdate,
)
from .dependencies import (
    get_current_user,
    get_current_active_user,
    require_admin,
    auth_rate_limit,
    standard_rate_limit,
)

router = APIRouter()


@router.post("/login", response_model=LoginResponse)
async def login(
    request: Request,
    login_request: LoginRequest = None,
    _: Any = Depends(auth_rate_limit),
):
    """Initiate MSAL authentication flow"""
    try:
        # Generate state for CSRF protection
        state = secrets.token_urlsafe(32)

        # Get authentication URL from MSAL
        auth_url, state = msal_service.get_auth_url(state)

        # Store state in session for validation
        session_id = secrets.token_urlsafe(32)
        msal_service.store_session_data(
            session_id,
            {
                "state": state,
                "redirect_url": login_request.redirect_url if login_request else None,
            },
            expire_seconds=600,  # 10 minutes
        )

        response = LoginResponse(auth_url=auth_url, state=state)

        # Set session cookie
        response_obj = Response(content=response.model_dump_json())
        response_obj.set_cookie(
            key="session_id",
            value=session_id,
            max_age=600,
            secure=True if request.url.scheme == "https" else False,
            httponly=True,
            samesite="lax",
        )

        logger.info(f"Login initiated for session {session_id}")
        return response

    except Exception as e:
        logger.error(f"Login initiation failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication service unavailable",
        )


@router.get("/callback")
async def auth_callback(
    request: Request,
    code: str = None,
    state: str = None,
    error: str = None,
    error_description: str = None,
    _: Any = Depends(auth_rate_limit),
):
    """Handle MSAL authentication callback"""

    # Check for authentication errors
    if error:
        logger.error(f"Authentication error: {error} - {error_description}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Authentication failed: {error_description or error}",
        )

    if not code or not state:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing authorization code or state",
        )

    try:
        # Retrieve session data to validate state
        session_id = request.cookies.get("session_id")
        if not session_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid session"
            )

        session_data = msal_service.get_session_data(session_id)
        if not session_data or session_data.get("state") != state:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid state parameter",
            )

        # Exchange code for tokens
        token_result = await msal_service.exchange_code_for_token(code, state)

        # Extract user information
        user = msal_service.extract_user_info(token_result)

        # Create JWT tokens
        jwt_token = msal_service.create_jwt_token(user)

        # Clean up session data
        msal_service.delete_session_data(session_id)

        # Determine redirect URL
        redirect_url = session_data.get("redirect_url", "/")

        # Create response with redirect
        response = RedirectResponse(url=redirect_url, status_code=302)

        # Set authentication cookies
        response.set_cookie(
            key="access_token",
            value=jwt_token.access_token,
            max_age=jwt_token.expires_in,
            secure=True if request.url.scheme == "https" else False,
            httponly=True,
            samesite="lax",
        )

        if jwt_token.refresh_token:
            response.set_cookie(
                key="refresh_token",
                value=jwt_token.refresh_token,
                max_age=7 * 24 * 3600,  # 7 days
                secure=True if request.url.scheme == "https" else False,
                httponly=True,
                samesite="lax",
            )

        logger.info(f"User {user.email} authenticated successfully")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Authentication callback failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication processing failed",
        )


@router.post("/refresh", response_model=Token)
async def refresh_token(request: Request, _: Any = Depends(auth_rate_limit)):
    """Refresh access token using refresh token"""
    refresh_token = request.cookies.get("refresh_token")

    if not refresh_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token not found"
        )

    try:
        new_token = msal_service.refresh_access_token(refresh_token)

        # Update cookies in response
        response = Response(content=new_token.model_dump_json())
        response.set_cookie(
            key="access_token",
            value=new_token.access_token,
            max_age=new_token.expires_in,
            secure=True if request.url.scheme == "https" else False,
            httponly=True,
            samesite="lax",
        )

        if new_token.refresh_token:
            response.set_cookie(
                key="refresh_token",
                value=new_token.refresh_token,
                max_age=7 * 24 * 3600,  # 7 days
                secure=True if request.url.scheme == "https" else False,
                httponly=True,
                samesite="lax",
            )

        return new_token

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Token refresh failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Token refresh failed",
        )


@router.post("/logout")
async def logout(request: Request, current_user: User = Depends(get_current_user)):
    """Logout user and clear authentication cookies"""

    # Create response
    response = Response(content='{"message": "Logged out successfully"}')

    # Clear authentication cookies
    response.delete_cookie(key="access_token")
    response.delete_cookie(key="refresh_token")
    response.delete_cookie(key="session_id")

    logger.info(f"User {current_user.email} logged out")
    return response


@router.get("/me", response_model=User)
async def get_current_user_info(
    current_user: User = Depends(get_current_active_user),
    _: Any = Depends(standard_rate_limit),
):
    """Get current user information"""
    return current_user


@router.put("/me", response_model=User)
async def update_current_user(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_active_user),
    _: Any = Depends(standard_rate_limit),
):
    """Update current user information"""
    # In production, you'd update the user in the database
    # For now, we'll just return the current user with updated fields

    updated_fields = user_update.model_dump(exclude_unset=True)
    updated_user = current_user.model_copy(update=updated_fields)

    logger.info(f"User {current_user.email} updated profile")
    return updated_user


@router.get("/users", response_model=list[User])
async def list_users(
    admin_user: User = Depends(require_admin), _: Any = Depends(standard_rate_limit)
):
    """List all users (admin only)"""
    # In production, you'd fetch users from database
    # For now, return empty list
    return []


@router.post("/users", response_model=User)
async def create_user(
    user_create: UserCreate,
    admin_user: User = Depends(require_admin),
    _: Any = Depends(standard_rate_limit),
):
    """Create new user (admin only)"""
    # In production, you'd create user in database
    new_user = User(**user_create.model_dump())

    logger.info(f"Admin {admin_user.email} created user {new_user.email}")
    return new_user


@router.get("/health")
async def auth_health():
    """Authentication service health check"""
    try:
        # Test MSAL service
        test_url, _ = msal_service.get_auth_url("test-state")

        return {
            "status": "healthy",
            "service": "authentication",
            "msal_configured": bool(test_url),
        }
    except Exception as e:
        logger.error(f"Authentication health check failed: {str(e)}")
        return {"status": "unhealthy", "service": "authentication", "error": "An internal error occurred."}
