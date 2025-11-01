#!/bin/bash

##############################################################################
# Setup Keycloak Database
#
# This script ensures the Keycloak database and user exist in PostgreSQL.
# It can be run on both fresh installs and existing deployments.
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
        print_info "Using sudo for docker commands"
    else
        print_error "Cannot access docker. Please ensure docker is running."
        exit 1
    fi
fi

# Load environment variables from .env if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Configuration
POSTGRES_USER="${POSTGRES_USER:-echograph}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-changeme}"
KEYCLOAK_DB="${KEYCLOAK_DB:-keycloak}"
KEYCLOAK_DB_USER="${KEYCLOAK_DB_USER:-keycloak}"
KEYCLOAK_DB_PASSWORD="${KEYCLOAK_DB_PASSWORD:-keycloak_changeme}"

print_info "Setting up Keycloak database..."
echo "  PostgreSQL user: $POSTGRES_USER"
echo "  Keycloak database: $KEYCLOAK_DB"
echo "  Keycloak user: $KEYCLOAK_DB_USER"

# Wait for postgres to be ready
print_info "Waiting for PostgreSQL to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if $DOCKER_COMPOSE exec -T postgres pg_isready -U $POSTGRES_USER > /dev/null 2>&1; then
        print_success "PostgreSQL is ready"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "PostgreSQL did not become ready in time"
        print_info "Checking if postgres container is running..."
        $DOCKER_COMPOSE ps postgres
        exit 1
    fi
    sleep 1
done

# Create Keycloak database and user
print_info "Creating Keycloak database and user..."

$DOCKER_COMPOSE exec -T postgres psql -U $POSTGRES_USER -d postgres <<-EOSQL
    -- Create keycloak user if not exists
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$KEYCLOAK_DB_USER') THEN
            CREATE USER $KEYCLOAK_DB_USER WITH PASSWORD '$KEYCLOAK_DB_PASSWORD';
            RAISE NOTICE 'User $KEYCLOAK_DB_USER created';
        ELSE
            RAISE NOTICE 'User $KEYCLOAK_DB_USER already exists';
        END IF;
    END
    \$\$;

    -- Create keycloak database if not exists
    SELECT 'CREATE DATABASE $KEYCLOAK_DB OWNER $KEYCLOAK_DB_USER'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$KEYCLOAK_DB')\gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE $KEYCLOAK_DB TO $KEYCLOAK_DB_USER;
EOSQL

if [ $? -eq 0 ]; then
    print_success "Keycloak database setup completed"
else
    print_error "Failed to setup Keycloak database"
    exit 1
fi

# Verify database was created
print_info "Verifying Keycloak database..."
DB_EXISTS=$($DOCKER_COMPOSE exec -T postgres psql -U $POSTGRES_USER -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$KEYCLOAK_DB'")

if [ "$DB_EXISTS" = "1" ]; then
    print_success "Keycloak database '$KEYCLOAK_DB' verified"
else
    print_error "Keycloak database '$KEYCLOAK_DB' not found"
    exit 1
fi

print_success "✓ Keycloak database setup complete!"
print_info ""
print_info "You can now restart Keycloak:"
print_info "  $DOCKER_COMPOSE restart keycloak"
