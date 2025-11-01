#!/bin/bash

##############################################################################
# Keycloak Diagnostic Script
#
# This script helps diagnose why Keycloak is not starting properly
##############################################################################

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

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Detect if we need sudo for docker commands
DOCKER_COMPOSE="docker compose"
if ! docker ps > /dev/null 2>&1; then
    if sudo docker ps > /dev/null 2>&1; then
        DOCKER_COMPOSE="sudo docker compose"
    else
        print_error "Cannot access docker. Please ensure docker is running."
        exit 1
    fi
fi

echo "=========================================="
echo "Keycloak Diagnostic Report"
echo "=========================================="
echo ""

# 1. Check if .env file exists
print_info "Checking environment configuration..."
if [ -f .env ]; then
    print_success ".env file exists"

    # Load it
    set -a
    source .env
    set +a

    # Check for required Keycloak variables
    MISSING_VARS=()

    [ -z "$KEYCLOAK_ADMIN_PASSWORD" ] && MISSING_VARS+=("KEYCLOAK_ADMIN_PASSWORD")
    [ -z "$KEYCLOAK_DB_PASSWORD" ] && MISSING_VARS+=("KEYCLOAK_DB_PASSWORD")

    if [ ${#MISSING_VARS[@]} -gt 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${MISSING_VARS[@]}"; do
            echo "  - $var"
        done
        print_warning "Please set these in your .env file"
    else
        print_success "All required Keycloak environment variables are set"
    fi
else
    print_error ".env file not found"
    print_info "Please copy .env.example to .env and configure it"
    exit 1
fi

echo ""

# 2. Check if PostgreSQL is running
print_info "Checking PostgreSQL status..."
if $DOCKER_COMPOSE ps postgres | grep -q "Up"; then
    print_success "PostgreSQL container is running"

    # Check if it's healthy
    if $DOCKER_COMPOSE ps postgres | grep -q "healthy"; then
        print_success "PostgreSQL is healthy"
    else
        print_warning "PostgreSQL is running but not healthy yet"
    fi
else
    print_error "PostgreSQL container is not running"
fi

echo ""

# 3. Check if Keycloak database exists
print_info "Checking Keycloak database..."
KEYCLOAK_DB="${KEYCLOAK_DB:-keycloak}"
DB_EXISTS=$($DOCKER_COMPOSE exec -T postgres psql -U ${POSTGRES_USER:-echograph} -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$KEYCLOAK_DB'" 2>/dev/null)

if [ "$DB_EXISTS" = "1" ]; then
    print_success "Keycloak database '$KEYCLOAK_DB' exists"
else
    print_error "Keycloak database '$KEYCLOAK_DB' does not exist"
    print_info "Run this to create it:"
    print_info "  cd ~/EchoGraph2 && ./scripts/setup-keycloak-database.sh"
fi

echo ""

# 4. Check Keycloak container status
print_info "Checking Keycloak container..."
if $DOCKER_COMPOSE ps keycloak | grep -q "Up"; then
    print_success "Keycloak container is running"

    # Check if it's healthy
    if $DOCKER_COMPOSE ps keycloak | grep -q "healthy"; then
        print_success "Keycloak is healthy"
    else
        print_warning "Keycloak is running but not healthy"
        print_info "Checking recent logs for errors..."
        echo ""
        print_info "Last 30 lines of Keycloak logs:"
        echo "----------------------------------------"
        $DOCKER_COMPOSE logs --tail=30 keycloak 2>&1
        echo "----------------------------------------"
    fi
else
    print_error "Keycloak container is not running"
    print_info "Checking why it stopped..."
    echo ""
    print_info "Last 50 lines of Keycloak logs:"
    echo "----------------------------------------"
    $DOCKER_COMPOSE logs --tail=50 keycloak 2>&1
    echo "----------------------------------------"
fi

echo ""

# 5. Check Keycloak endpoint
print_info "Checking Keycloak HTTP endpoint..."
if curl -sf http://localhost:8080 > /dev/null 2>&1; then
    print_success "Keycloak is responding on http://localhost:8080"
else
    print_error "Keycloak is not responding on http://localhost:8080"
fi

echo ""
echo "=========================================="
echo "Diagnostic Summary"
echo "=========================================="
echo ""

# Check all required services
ALL_OK=true

# Check if database exists
if [ "$DB_EXISTS" != "1" ]; then
    print_error "Action needed: Create Keycloak database"
    echo "  Run: cd ~/EchoGraph2 && ./scripts/setup-keycloak-database.sh"
    ALL_OK=false
fi

# Check if Keycloak is running
if ! $DOCKER_COMPOSE ps keycloak | grep -q "healthy"; then
    print_error "Action needed: Keycloak is not healthy"
    echo "  1. Check the logs above for error messages"
    echo "  2. Ensure KEYCLOAK_ADMIN_PASSWORD is set in .env"
    echo "  3. Ensure KEYCLOAK_DB_PASSWORD is set in .env"
    echo "  4. Try restarting: $DOCKER_COMPOSE restart keycloak"
    ALL_OK=false
fi

if [ "$ALL_OK" = true ]; then
    echo ""
    print_success "All checks passed! Keycloak should be working."
    echo ""
    print_info "Keycloak Admin Console: http://localhost:8080/admin"
    print_info "Username: ${KEYCLOAK_ADMIN:-admin}"
fi

echo ""
