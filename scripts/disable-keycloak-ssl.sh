#!/bin/bash

##############################################################################
# Disable Keycloak SSL Requirement
#
# This script disables the SSL/HTTPS requirement for the master realm
# in Keycloak, allowing HTTP access from external IPs.
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

print_info "Disabling SSL requirement in Keycloak master realm..."

# Wait for Keycloak to be ready
print_info "Waiting for Keycloak to be ready..."
sleep 10

# Get admin token
print_info "Authenticating with Keycloak admin..."
TOKEN_RESPONSE=$($DOCKER_COMPOSE exec -T keycloak /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user "$KEYCLOAK_ADMIN" \
    --password "$KEYCLOAK_ADMIN_PASSWORD" 2>&1)

if [ $? -ne 0 ]; then
    print_error "Failed to authenticate with Keycloak"
    echo "$TOKEN_RESPONSE"
    exit 1
fi

print_success "Authenticated successfully"

# Disable SSL requirement for master realm
print_info "Disabling SSL requirement for master realm..."
$DOCKER_COMPOSE exec -T keycloak /opt/keycloak/bin/kcadm.sh update realms/master \
    -s sslRequired=NONE \
    2>&1

if [ $? -eq 0 ]; then
    print_success "SSL requirement disabled for master realm"
else
    print_error "Failed to disable SSL requirement"
    exit 1
fi

print_success "✓ Keycloak is now configured to accept HTTP connections!"
print_info ""
print_info "You can now access Keycloak at:"
print_info "  Admin Console: http://178.18.254.21:8080/admin"
print_info "  Username: $KEYCLOAK_ADMIN"
