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

GENERATED_REALM_FILE=""

cleanup() {
    if [ -n "$GENERATED_REALM_FILE" ] && [ -f "$GENERATED_REALM_FILE" ]; then
        rm -f "$GENERATED_REALM_FILE"
    fi
}

strip_trailing_slash() {
    local value="$1"
    while [[ "$value" == */ ]]; do
        value="${value%/}"
    done
    echo "$value"
}

convert_ws_to_http() {
    local value="$1"
    case "$value" in
        wss://*) echo "https://${value#wss://}" ;;
        ws://*) echo "http://${value#ws://}" ;;
        *) echo "$value" ;;
    esac
}

make_redirect_uri() {
    local origin
    origin=$(strip_trailing_slash "$1")
    if [ -z "$origin" ]; then
        echo ""
    else
        echo "${origin}/*"
    fi
}

generate_realm_file() {
    local template_file="$1"
    local output_file="$2"

    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is required to generate the Keycloak realm configuration"
        exit 1
    fi

    local default_frontend="http://localhost:3000"
    local frontend_url="${FRONTEND_PUBLIC_URL:-${NEXT_PUBLIC_FRONTEND_URL:-$default_frontend}}"
    local api_url="${NEXT_PUBLIC_API_URL:-http://localhost:8000}"
    local ws_url="${NEXT_PUBLIC_WS_URL:-ws://localhost:8000}"
    local keycloak_public_url="${KEYCLOAK_PUBLIC_URL:-http://localhost:8080}"

    local frontend_origin="$(strip_trailing_slash "$frontend_url")"
    local api_origin="$(strip_trailing_slash "$api_url")"
    local ws_origin="$(strip_trailing_slash "$(convert_ws_to_http "$ws_url")")"
    local keycloak_origin="$(strip_trailing_slash "$keycloak_public_url")"

    local frontend_redirect="$(make_redirect_uri "$frontend_origin")"
    local api_redirect="$(make_redirect_uri "$api_origin")"
    local logout_uris="$frontend_redirect"

    print_info "Generating realm configuration with dynamic URLs"
    echo "  Frontend origin: ${frontend_origin:-<not set>}"
    echo "  API origin: ${api_origin:-<not set>}"
    echo "  WebSocket origin: ${ws_origin:-<not set>}"
    echo "  Keycloak public origin: ${keycloak_origin:-<not set>}"

    jq \
        --arg apiOrigin "$api_origin" \
        --arg apiRedirect "$api_redirect" \
        --arg frontendOrigin "$frontend_origin" \
        --arg frontendRedirect "$frontend_redirect" \
        --arg wsOrigin "$ws_origin" \
        --arg keycloakOrigin "$keycloak_origin" \
        --arg logoutUris "$logout_uris" \
        '
        def nonempty(vals):
          [vals[] | select(. != null and . != "")];

        (.clients[] | select(.clientId == "echograph-api") | .redirectUris) =
          (nonempty([$apiRedirect])) |

        (.clients[] | select(.clientId == "echograph-api") | .webOrigins) =
          (nonempty([$apiOrigin, $frontendOrigin, $wsOrigin, $keycloakOrigin]) + ["*"] | unique) |

        (.clients[] | select(.clientId == "echograph-frontend") | .redirectUris) =
          (nonempty([$frontendRedirect])) |

        (.clients[] | select(.clientId == "echograph-frontend") | .webOrigins) =
          (nonempty([$frontendOrigin]) + ["*"] | unique) |

        (.clients[] | select(.clientId == "echograph-frontend") | .attributes["post.logout.redirect.uris"]) =
          $logoutUris
        ' "$template_file" > "$output_file"
}

trap cleanup EXIT

# Determine script location for template resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration from environment or defaults
KEYCLOAK_URL="${KEYCLOAK_SERVER_URL:-http://localhost:8080}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD}"
REALM_NAME="${KEYCLOAK_REALM:-echograph}"
CLIENT_ID="${KEYCLOAK_CLIENT_ID:-echograph-api}"
CLIENT_SECRET="${KEYCLOAK_CLIENT_SECRET}"

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
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 --connect-timeout 3 "$KEYCLOAK_URL/realms/master" 2>/dev/null || echo "000")

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

TOKEN_RESPONSE=$(timeout 15 curl -sf --max-time 10 --connect-timeout 5 -X POST \
    "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$KEYCLOAK_ADMIN" \
    -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" 2>/dev/null)

TOKEN_EXIT=$?

if [ $TOKEN_EXIT -ne 0 ]; then
    if [ $TOKEN_EXIT -eq 124 ]; then
        print_error "Timeout while authenticating with Keycloak"
    else
        print_error "Failed to authenticate with Keycloak (exit code: $TOKEN_EXIT)"
    fi
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

REALM_EXISTS=false
# Use timeout command to ensure curl doesn't hang
REALM_LOOKUP=$(timeout 10 curl -sf --max-time 10 --connect-timeout 5 -X GET \
    "$KEYCLOAK_URL/admin/realms/$REALM_NAME" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" 2>/dev/null)

CURL_EXIT=$?

if [ $CURL_EXIT -eq 0 ] && [ -n "$REALM_LOOKUP" ]; then
    print_info "Realm '$REALM_NAME' exists - it will be updated"
    REALM_EXISTS=true
elif [ $CURL_EXIT -eq 124 ]; then
    print_error "Timeout while checking realm existence"
    print_info "Assuming realm does not exist - will attempt to create it"
    REALM_EXISTS=false
else
    print_info "Realm does not exist - it will be created"
    REALM_EXISTS=false
fi

##############################################################################
# Step 4: Import realm configuration (if needed)
##############################################################################

TEMPLATE_FILE="$SCRIPT_DIR/echograph-realm.json"

if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Realm configuration template not found: $TEMPLATE_FILE"
    exit 1
fi

GENERATED_REALM_FILE="$(mktemp /tmp/echograph-realm.XXXXXX.json)"

generate_realm_file "$TEMPLATE_FILE" "$GENERATED_REALM_FILE"
if [ "$REALM_EXISTS" = true ]; then
    print_info "Updating existing realm configuration..."

    HTTP_CODE=$(timeout 40 curl -s -o /tmp/keycloak_realm_update_response.$$ -w "%{http_code}" --max-time 30 --connect-timeout 10 -X PUT \
        "$KEYCLOAK_URL/admin/realms/$REALM_NAME" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$GENERATED_REALM_FILE" 2>/dev/null || true)

    if [ "$HTTP_CODE" != "204" ]; then
        print_error "Failed to update realm configuration (HTTP $HTTP_CODE)"
        if [ -f /tmp/keycloak_realm_update_response.$$ ]; then
            cat /tmp/keycloak_realm_update_response.$$
            rm -f /tmp/keycloak_realm_update_response.$$
        fi
        exit 1
    fi

    rm -f /tmp/keycloak_realm_update_response.$$
    print_success "Realm updated successfully"
else
    print_info "Importing realm configuration..."

    HTTP_CODE=$(timeout 40 curl -s -o /tmp/keycloak_realm_import_response.$$ -w "%{http_code}" --max-time 30 --connect-timeout 10 -X POST \        "$KEYCLOAK_URL/admin/realms" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$GENERATED_REALM_FILE" 2>/dev/null || true)

    if [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "204" ]; then
        print_error "Failed to import realm configuration (HTTP $HTTP_CODE)"
        if [ -f /tmp/keycloak_realm_import_response.$$ ]; then
            cat /tmp/keycloak_realm_import_response.$$
            rm -f /tmp/keycloak_realm_import_response.$$
        fi
        exit 1
    fi

    rm -f /tmp/keycloak_realm_import_response.$$
    print_success "Realm imported successfully"
    print_info "Using existing realm"
fi

##############################################################################
# Step 5: Update client secret for echograph-api
##############################################################################

print_info "Configuring client secret for '$CLIENT_ID'..."

# Get the client's internal ID
CLIENT_UUID=$(timeout 15 curl -sf --max-time 10 --connect-timeout 5 -X GET \
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
UPDATE_RESPONSE=$(curl -sf --max-time 10 --connect-timeout 5 -X POST \
    "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients/$CLIENT_UUID/client-secret" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"value\":\"$CLIENT_SECRET\"}" 2>/dev/null)

if [ $? -ne 0 ]; then
    print_warning "Could not set custom client secret - using generated one"
    # Get the generated secret
    SECRET_RESPONSE=$(curl -sf --max-time 10 --connect-timeout 5 -X GET \
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
REALM_CHECK=$(curl -sf --max-time 10 --connect-timeout 5 -X GET \
    "$KEYCLOAK_URL/realms/$REALM_NAME" \
    -H "Content-Type: application/json" 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "Realm verification failed"
    exit 1
fi

print_success "Realm is accessible"

# Check OIDC configuration
OIDC_CONFIG=$(curl -sf --max-time 10 --connect-timeout 5 -X GET \
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
