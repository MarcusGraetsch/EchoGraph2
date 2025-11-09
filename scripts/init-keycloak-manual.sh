#!/bin/bash

##############################################################################
# Manual Keycloak Initialization Script
#
# Run this script to initialize the Keycloak realm if it failed during
# deployment or needs to be recreated.
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Keycloak Realm Initialization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Load environment variables from .env file
ENV_FILE="$REPO_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    print_info "Loading environment variables from .env"
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    print_error ".env file not found at $ENV_FILE"
    echo "Please run the deployment script first or create a .env file"
    exit 1
fi

# Check if Keycloak is running
print_info "Checking if Keycloak is running..."
if ! docker ps | grep -q echograph-keycloak; then
    print_error "Keycloak container is not running"
    echo "Start it with: cd $REPO_DIR && docker-compose -f docker-compose.prod.yml up -d keycloak"
    exit 1
fi

print_success "Keycloak container is running"

# Export required variables for init script
export KEYCLOAK_SERVER_URL="http://localhost:8080"
export KEYCLOAK_ADMIN
export KEYCLOAK_ADMIN_PASSWORD
export KEYCLOAK_REALM
export KEYCLOAK_CLIENT_ID
export KEYCLOAK_CLIENT_SECRET
export KEYCLOAK_FRONTEND_CLIENT_ID

print_info "Configuration:"
echo "  Keycloak URL: http://localhost:8080"
echo "  Admin User: $KEYCLOAK_ADMIN"
echo "  Realm: $KEYCLOAK_REALM"
echo "  API Client: $KEYCLOAK_CLIENT_ID"
echo "  Frontend Client: $KEYCLOAK_FRONTEND_CLIENT_ID"
echo ""

# Run initialization script
if [ -f "$REPO_DIR/keycloak/init-keycloak.sh" ]; then
    print_info "Running Keycloak initialization script..."
    echo ""

    if bash "$REPO_DIR/keycloak/init-keycloak.sh"; then
        echo ""
        print_success "Keycloak realm initialized successfully!"
        echo ""
        echo "You can now access:"
        echo "  - Frontend: http://YOUR_SERVER_IP:3000"
        echo "  - Keycloak Admin: http://YOUR_SERVER_IP:8080/admin"
        echo ""
    else
        echo ""
        print_error "Keycloak initialization failed"
        echo ""
        echo "Troubleshooting steps:"
        echo "  1. Check Keycloak logs: docker logs echograph-keycloak"
        echo "  2. Verify Keycloak is fully started (may take 2-3 minutes)"
        echo "  3. Check if admin password is correct in .env"
        echo "  4. Try accessing http://localhost:8080/admin manually"
        echo ""
        exit 1
    fi
else
    print_error "Keycloak initialization script not found"
    echo "Expected location: $REPO_DIR/keycloak/init-keycloak.sh"
    exit 1
fi
