"""Authentication router.

DEPRECATED: This router contains legacy authentication endpoints.
With Keycloak integration, use Keycloak for user registration and login:
- Registration: Use Keycloak's registration page or admin console
- Login: Use Keycloak's OIDC flow (handled by frontend)
- Token management: Handled by Keycloak

The /me endpoint is still available to get current user info from Keycloak token.
"""

from datetime import timedelta, datetime
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from database import get_db
from models import User
from schemas import Token, UserCreate, UserResponse
from keycloak_auth import get_current_active_user, KeycloakUser
from auth import (
    authenticate_user,
    create_access_token,
    get_password_hash
)
from config import settings

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED, deprecated=True)
async def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Register a new user.

    DEPRECATED: Use Keycloak registration instead.
    This endpoint is kept for backward compatibility but should not be used with Keycloak.

    Args:
        user_data: User registration data
        db: Database session

    Returns:
        Created user

    Raises:
        HTTPException: If email or username already exists
    """
    # Check if email exists
    if db.query(User).filter(User.email == user_data.email).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    # Check if username exists
    if db.query(User).filter(User.username == user_data.username).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken"
        )

    # Create user
    user = User(
        email=user_data.email,
        username=user_data.username,
        full_name=user_data.full_name,
        hashed_password=get_password_hash(user_data.password)
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


@router.post("/token", response_model=Token, deprecated=True)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    """Login and get access token.

    DEPRECATED: Use Keycloak OIDC flow instead.
    This endpoint is kept for backward compatibility but should not be used with Keycloak.

    Args:
        form_data: OAuth2 form data
        db: Database session

    Returns:
        Access token

    Raises:
        HTTPException: If authentication fails
    """
    user = authenticate_user(db, form_data.username, form_data.password)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Update last login
    user.last_login = datetime.utcnow()
    db.commit()

    # Create access token
    access_token_expires = timedelta(minutes=settings.api_access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": user.email},
        expires_delta=access_token_expires
    )

    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me")
async def get_current_user(current_user: KeycloakUser = Depends(get_current_active_user)):
    """Get current user information from Keycloak token.

    Args:
        current_user: Current authenticated user from Keycloak

    Returns:
        User information from Keycloak
    """
    return {
        "id": current_user.id,
        "username": current_user.username,
        "email": current_user.email,
        "email_verified": current_user.email_verified,
        "first_name": current_user.first_name,
        "last_name": current_user.last_name,
        "is_active": current_user.is_active,
        "is_admin": current_user.is_admin,
        "roles": current_user.roles
    }
