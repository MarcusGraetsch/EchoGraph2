#!/bin/bash

##############################################################################
# Configure Keycloak for HTTP External Access
#
# This script configures Keycloak to work with external IPs over HTTP by:
# 1. Disabling SSL requirement
# 2. Setting the frontend URL to the external IP
# 3. Configuring hostname settings
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Detect if we need sudo for docker commands
DOCKER_COMPOSE="docker compose"
if ! docker ps > /dev/null 2>&1; then
    if sudo docker ps > /dev/null 2>&1; then
        DOCKER_COMPOSE="sudo docker compose"
    fi
fi

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD}"
EXTERNAL_URL="${KEYCLOAK_HOSTNAME_URL:-http://178.18.254.21:8080}"

echo "=========================================="
echo "Keycloak HTTP External Access Setup"
echo "=========================================="
echo ""
print_info "Configuration:"
echo "  Admin user: $KEYCLOAK_ADMIN"
echo "  External URL: $EXTERNAL_URL"
echo ""

# Check if Keycloak is running
print_info "Checking if Keycloak is running..."
if ! $DOCKER_COMPOSE ps keycloak | grep -q "Up"; then
    print_error "Keycloak is not running"
    print_info "Start it with: $DOCKER_COMPOSE up -d keycloak"
    exit 1
fi
print_success "Keycloak is running"

# Wait for Keycloak to be ready
print_info "Waiting for Keycloak to be fully ready..."
MAX_WAIT=60
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if $DOCKER_COMPOSE exec -T keycloak curl -sf http://localhost:8080/realms/master > /dev/null 2>&1; then
        break
    fi
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
        print_error "Keycloak did not become ready in time"
        exit 1
    fi
    sleep 2
    echo -n "."
done
echo ""
print_success "Keycloak is ready"

# Configure kcadm.sh
print_info "Authenticating with Keycloak admin..."
AUTH_OUTPUT=$($DOCKER_COMPOSE exec -T keycloak /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user "$KEYCLOAK_ADMIN" \
    --password "$KEYCLOAK_ADMIN_PASSWORD" 2>&1)

if [ $? -ne 0 ]; then
    print_error "Failed to authenticate with Keycloak"
    echo "$AUTH_OUTPUT"
    exit 1
fi
print_success "Authenticated successfully"

# Step 1: Disable SSL requirement
print_info "Disabling SSL requirement for master realm..."
$DOCKER_COMPOSE exec -T keycloak /opt/keycloak/bin/kcadm.sh update realms/master \
    -s sslRequired=NONE \
    > /dev/null 2>&1

if [ $? -eq 0 ]; then
    print_success "SSL requirement disabled"
else
    print_warning "Could not disable SSL requirement (may already be disabled)"
fi

# Step 2: Set frontend URL
print_info "Configuring frontend URL to $EXTERNAL_URL..."
$DOCKER_COMPOSE exec -T keycloak /opt/keycloak/bin/kcadm.sh update realms/master \
    -s "attributes.frontendUrl=$EXTERNAL_URL" \
    > /dev/null 2>&1

if [ $? -eq 0 ]; then
    print_success "Frontend URL configured"
else
    print_warning "Could not set frontend URL"
fi

# Step 3: Update admin URL
print_info "Configuring admin URL..."
$DOCKER_COMPOSE exec -T keycloak /opt/keycloak/bin/kcadm.sh update realms/master \
    -s "attributes.adminUrl=$EXTERNAL_URL" \
    > /dev/null 2>&1

if [ $? -eq 0 ]; then
    print_success "Admin URL configured"
else
    print_warning "Could not set admin URL"
fi

# Step 4: Verify configuration
print_info "Verifying configuration..."
SSL_REQUIRED=$($DOCKER_COMPOSE exec -T keycloak /opt/keycloak/bin/kcadm.sh get realms/master --fields sslRequired 2>/dev/null | grep -o '"sslRequired" : "[^"]*"' | cut -d'"' -f4)

if [ "$SSL_REQUIRED" = "NONE" ]; then
    print_success "SSL requirement is disabled (sslRequired=$SSL_REQUIRED)"
else
    print_warning "SSL requirement: $SSL_REQUIRED"
fi

echo ""
echo "=========================================="
print_success "Keycloak configuration complete!"
echo "=========================================="
echo ""
print_info "You can now access Keycloak at:"
print_info "  Admin Console: ${EXTERNAL_URL}/admin"
print_info "  Username: $KEYCLOAK_ADMIN"
echo ""
print_warning "Note: You may need to clear your browser cache or use incognito mode"
print_warning "if you're still seeing localhost redirects."
echo ""
