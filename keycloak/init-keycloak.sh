#!/bin/bash

##############################################################################
# Keycloak Initialization Script
#
# This script automatically configures Keycloak with the EchoGraph realm.
# It imports the realm configuration and sets up the client credentials.
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Configuration from environment or defaults
KEYCLOAK_URL="${KEYCLOAK_SERVER_URL:-http://localhost:8080}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD}"
REALM_NAME="${KEYCLOAK_REALM:-echograph}"
CLIENT_ID="${KEYCLOAK_CLIENT_ID:-echograph-api}"
CLIENT_SECRET="${KEYCLOAK_CLIENT_SECRET}"
REALM_FILE="/tmp/echograph-realm.json"

# Check if running in container or on host
if [ -f "/.dockerenv" ]; then
    print_info "Running inside Docker container"
    KEYCLOAK_URL="http://keycloak:8080"
fi

print_info "Starting Keycloak initialization..."
echo "  Keycloak URL: $KEYCLOAK_URL"
echo "  Realm: $REALM_NAME"
echo "  Client ID: $CLIENT_ID"

##############################################################################
# Step 1: Wait for Keycloak to be ready
##############################################################################

print_info "Waiting for Keycloak to be ready..."
print_info "This may take 2-3 minutes for Keycloak to fully start..."

MAX_RETRIES=90  # 3 minutes with 2 second intervals
RETRY_COUNT=0
KEYCLOAK_READY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Try to access the master realm endpoint (more reliable than /health/ready)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$KEYCLOAK_URL/realms/master" 2>/dev/null || echo "000")

    # 200, 302, 404, or even 403 means Keycloak is responding
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "403" ]; then
        KEYCLOAK_READY=true
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "Keycloak did not become ready in time"
        print_info "Last HTTP code: $HTTP_CODE"
        print_info "Try checking: docker compose logs keycloak"
        exit 1
    fi

    # Print progress every 10 retries
    if [ $((RETRY_COUNT % 10)) -eq 0 ]; then
        echo -n " [${RETRY_COUNT}s] "
    else
        echo -n "."
    fi
    sleep 2
done

if [ "$KEYCLOAK_READY" = true ]; then
    echo ""
    print_success "Keycloak is ready!"
fi

##############################################################################
# Step 2: Get admin access token
##############################################################################

print_info "Authenticating as Keycloak admin..."

TOKEN_RESPONSE=$(curl -sf --max-time 10 -X POST \
    "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$KEYCLOAK_ADMIN" \
    -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "Failed to authenticate with Keycloak"
    exit 1
fi

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')

if [ -z "$ACCESS_TOKEN" ]; then
    print_error "Could not extract access token"
    exit 1
fi

print_success "Authenticated successfully"

##############################################################################
# Step 3: Check if realm already exists
##############################################################################

print_info "Checking if realm '$REALM_NAME' exists..."

REALM_EXISTS=$(curl -sf --max-time 10 -X GET \
    "$KEYCLOAK_URL/admin/realms/$REALM_NAME" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$REALM_EXISTS" ]; then
    print_warning "Realm '$REALM_NAME' already exists - skipping import"
    REALM_CREATED=false
else
    print_info "Realm does not exist - will create it"
    REALM_CREATED=true
fi

##############################################################################
# Step 4: Import realm configuration (if needed)
##############################################################################

if [ "$REALM_CREATED" = true ]; then
    print_info "Importing realm configuration..."

    # The realm file should be mounted or copied to this location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ ! -f "$SCRIPT_DIR/echograph-realm.json" ]; then
        print_error "Realm configuration file not found: $SCRIPT_DIR/echograph-realm.json"
        exit 1
    fi

    IMPORT_RESPONSE=$(curl -sf --max-time 30 -X POST \
        "$KEYCLOAK_URL/admin/realms" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$SCRIPT_DIR/echograph-realm.json" 2>/dev/null)

    if [ $? -ne 0 ]; then
        print_error "Failed to import realm configuration"
        exit 1
    fi

    print_success "Realm imported successfully"
else
    print_info "Using existing realm"
fi

##############################################################################
# Step 5: Update client secret for echograph-api
##############################################################################

print_info "Configuring client secret for '$CLIENT_ID'..."

# Get the client's internal ID
CLIENT_UUID=$(curl -sf --max-time 10 -X GET \
    "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients?clientId=$CLIENT_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" 2>/dev/null | \
    grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')

if [ -z "$CLIENT_UUID" ]; then
    print_error "Could not find client '$CLIENT_ID'"
    exit 1
fi

print_info "Found client UUID: $CLIENT_UUID"

# Update client secret
UPDATE_RESPONSE=$(curl -sf --max-time 10 -X POST \
    "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients/$CLIENT_UUID/client-secret" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"value\":\"$CLIENT_SECRET\"}" 2>/dev/null)

if [ $? -ne 0 ]; then
    print_warning "Could not set custom client secret - using generated one"
    # Get the generated secret
    SECRET_RESPONSE=$(curl -sf --max-time 10 -X GET \
        "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients/$CLIENT_UUID/client-secret" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" 2>/dev/null)

    CLIENT_SECRET=$(echo "$SECRET_RESPONSE" | grep -o '"value":"[^"]*' | sed 's/"value":"//')
    print_info "Using generated secret (update .env with this value): $CLIENT_SECRET"
else
    print_success "Client secret configured"
fi

##############################################################################
# Step 6: Verify configuration
##############################################################################

print_info "Verifying configuration..."

# Check realm
REALM_CHECK=$(curl -sf --max-time 10 -X GET \
    "$KEYCLOAK_URL/realms/$REALM_NAME" \
    -H "Content-Type: application/json" 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "Realm verification failed"
    exit 1
fi

print_success "Realm is accessible"

# Check OIDC configuration
OIDC_CONFIG=$(curl -sf --max-time 10 -X GET \
    "$KEYCLOAK_URL/realms/$REALM_NAME/.well-known/openid-configuration" \
    -H "Content-Type: application/json" 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "OIDC configuration is not accessible"
    exit 1
fi

print_success "OIDC endpoints are configured"

##############################################################################
# Summary
##############################################################################

echo ""
print_success "=========================================="
print_success "Keycloak initialization completed!"
print_success "=========================================="
echo ""
echo "Realm Information:"
echo "  Realm: $REALM_NAME"
echo "  Clients: echograph-api, echograph-frontend"
echo "  Default roles: user, admin, echograph-admin"
echo ""
echo "OIDC Endpoints:"
echo "  Authorization: $KEYCLOAK_URL/realms/$REALM_NAME/protocol/openid-connect/auth"
echo "  Token: $KEYCLOAK_URL/realms/$REALM_NAME/protocol/openid-connect/token"
echo "  UserInfo: $KEYCLOAK_URL/realms/$REALM_NAME/protocol/openid-connect/userinfo"
echo ""
echo "Admin Console: $KEYCLOAK_URL/admin"
echo "  Username: $KEYCLOAK_ADMIN"
echo "  Password: [from environment]"
echo ""
echo "Test User:"
echo "  Username: admin"
echo "  Password: admin (change on first login)"
echo ""
print_warning "Remember to change the default admin password!"
echo ""
