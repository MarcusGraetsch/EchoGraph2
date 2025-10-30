"""
Keycloak authentication module for EchoGraph API.

This module provides OIDC/OAuth2 authentication using Keycloak.
It validates JWT tokens and extracts user information for API endpoints.
"""

import os
from typing import Optional, Dict, Any
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from keycloak import KeycloakOpenID
from loguru import logger
import httpx


# Security scheme for bearer token
security = HTTPBearer()

# Keycloak configuration from environment
KEYCLOAK_SERVER_URL = os.getenv("KEYCLOAK_SERVER_URL", "http://keycloak:8080")
KEYCLOAK_REALM = os.getenv("KEYCLOAK_REALM", "echograph")
KEYCLOAK_CLIENT_ID = os.getenv("KEYCLOAK_CLIENT_ID", "echograph-api")
KEYCLOAK_CLIENT_SECRET = os.getenv("KEYCLOAK_CLIENT_SECRET")

# Initialize Keycloak OpenID client
keycloak_openid = KeycloakOpenID(
    server_url=KEYCLOAK_SERVER_URL,
    client_id=KEYCLOAK_CLIENT_ID,
    realm_name=KEYCLOAK_REALM,
    client_secret_key=KEYCLOAK_CLIENT_SECRET,
    verify=True
)


class KeycloakUser:
    """User object extracted from Keycloak token."""

    def __init__(self, token_info: Dict[str, Any]):
        self.id = token_info.get("sub")
        self.username = token_info.get("preferred_username")
        self.email = token_info.get("email")
        self.email_verified = token_info.get("email_verified", False)
        self.first_name = token_info.get("given_name")
        self.last_name = token_info.get("family_name")
        self.roles = token_info.get("realm_access", {}).get("roles", [])
        self.is_active = True
        self.is_admin = "admin" in self.roles or "echograph-admin" in self.roles

    def __repr__(self):
        return f"<KeycloakUser {self.username} ({self.email})>"


async def get_keycloak_public_key() -> str:
    """
    Retrieve Keycloak public key for token verification.

    Returns:
        str: The public key in PEM format
    """
    try:
        public_key = (
            "-----BEGIN PUBLIC KEY-----\n"
            + keycloak_openid.public_key()
            + "\n-----END PUBLIC KEY-----"
        )
        return public_key
    except Exception as e:
        logger.error(f"Failed to retrieve Keycloak public key: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service unavailable"
        )


async def verify_token(token: str) -> Dict[str, Any]:
    """
    Verify and decode a JWT token from Keycloak.

    Args:
        token: The JWT token to verify

    Returns:
        Dict containing the decoded token payload

    Raises:
        HTTPException: If token is invalid or expired
    """
    try:
        # Get Keycloak public key
        public_key = await get_keycloak_public_key()

        # Verify and decode token
        options = {
            "verify_signature": True,
            "verify_aud": False,  # Keycloak doesn't always include aud
            "verify_exp": True
        }

        token_info = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            options=options,
            audience=KEYCLOAK_CLIENT_ID
        )

        return token_info

    except JWTError as e:
        logger.warning(f"Token verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error(f"Token verification error: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service error"
        )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> KeycloakUser:
    """
    Dependency to get the current authenticated user from the request.

    This function extracts the JWT token from the Authorization header,
    verifies it with Keycloak, and returns a KeycloakUser object.

    Args:
        credentials: The HTTP bearer token from the request

    Returns:
        KeycloakUser: The authenticated user

    Raises:
        HTTPException: If authentication fails
    """
    token = credentials.credentials

    # Verify token and get user info
    token_info = await verify_token(token)

    # Create and return user object
    return KeycloakUser(token_info)


async def get_current_active_user(
    current_user: KeycloakUser = Depends(get_current_user)
) -> KeycloakUser:
    """
    Dependency to get the current active user.

    Args:
        current_user: The current user from get_current_user

    Returns:
        KeycloakUser: The active user

    Raises:
        HTTPException: If user is inactive
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )
    return current_user


async def get_current_admin_user(
    current_user: KeycloakUser = Depends(get_current_active_user)
) -> KeycloakUser:
    """
    Dependency to ensure the current user has admin privileges.

    Args:
        current_user: The current active user

    Returns:
        KeycloakUser: The admin user

    Raises:
        HTTPException: If user doesn't have admin role
    """
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required"
        )
    return current_user


async def check_keycloak_health() -> bool:
    """
    Check if Keycloak service is healthy and accessible.

    Returns:
        bool: True if Keycloak is healthy, False otherwise
    """
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{KEYCLOAK_SERVER_URL}/health/ready")
            return response.status_code == 200
    except Exception as e:
        logger.error(f"Keycloak health check failed: {e}")
        return False
