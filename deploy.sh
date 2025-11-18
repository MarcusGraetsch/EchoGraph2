#!/bin/bash

##############################################################################
# EchoGraph Automated Deployment Script
##############################################################################
# This script automatically:
# 1. Detects your VM's IP address
# 2. Generates .env configuration if needed
# 3. Starts all services with docker-compose
# 4. Initializes Keycloak
##############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}${BOLD}  EchoGraph Deployment${NC}"
echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════${NC}\n"

cd "$SCRIPT_DIR"

##############################################################################
# Step 1: Check and generate .env file
##############################################################################

echo -e "${YELLOW}[1/5] Checking environment configuration...${NC}"

NEEDS_ENV_GENERATION=false

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}  ⚠ .env file not found${NC}"
    NEEDS_ENV_GENERATION=true
elif grep -q "{{PUBLIC_IP}}" "$SCRIPT_DIR/.env" 2>/dev/null; then
    echo -e "${YELLOW}  ⚠ .env file contains placeholders${NC}"
    NEEDS_ENV_GENERATION=true
else
    # Check if .env has actual values (not empty)
    KEYCLOAK_URL=$(grep -E "^KEYCLOAK_HOSTNAME_URL=" .env | cut -d'=' -f2)
    PUBLIC_KEYCLOAK=$(grep -E "^KEYCLOAK_PUBLIC_URL=" .env | cut -d'=' -f2)

    if [ -z "$KEYCLOAK_URL" ] || [ -z "$PUBLIC_KEYCLOAK" ]; then
        echo -e "${YELLOW}  ⚠ .env file has empty values${NC}"
        NEEDS_ENV_GENERATION=true
    else
        echo -e "${GREEN}  ✓ .env file exists and is configured${NC}"
    fi
fi

if [ "$NEEDS_ENV_GENERATION" = true ]; then
    echo -e "${BLUE}  → Generating .env configuration automatically...${NC}"

    # Make sure scripts are executable
    chmod +x "$SCRIPT_DIR/scripts/setup-env.sh" "$SCRIPT_DIR/scripts/detect-ip.sh" 2>/dev/null || true

    # Check if setup script exists
    if [ ! -f "$SCRIPT_DIR/scripts/setup-env.sh" ]; then
        echo -e "${RED}  ✗ Error: scripts/setup-env.sh not found${NC}"
        echo -e "${YELLOW}  Please ensure all repository files are present${NC}"
        exit 1
    fi

    # Run setup-env.sh automatically (non-interactive)
    echo "y" | "$SCRIPT_DIR/scripts/setup-env.sh" || "$SCRIPT_DIR/scripts/setup-env.sh"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ .env configuration generated successfully${NC}"
    else
        echo -e "${RED}  ✗ Error: Failed to generate .env configuration${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}  ✓ Using existing .env configuration${NC}"
fi

echo ""

##############################################################################
# Step 2: Validate configuration
##############################################################################

echo -e "${YELLOW}[2/5] Validating configuration...${NC}"

# Check if .env exists now
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${RED}  ✗ .env file still missing after generation${NC}"
    exit 1
fi

# Extract and validate configured values
KEYCLOAK_HOSTNAME=$(grep -E "^KEYCLOAK_HOSTNAME_URL=" .env | cut -d'=' -f2)
PUBLIC_KEYCLOAK=$(grep -E "^KEYCLOAK_PUBLIC_URL=" .env | cut -d'=' -f2)
CONFIGURED_IP=$(echo "$KEYCLOAK_HOSTNAME" | cut -d'/' -f3 | cut -d':' -f1)

if [ -z "$KEYCLOAK_HOSTNAME" ] || [ -z "$PUBLIC_KEYCLOAK" ]; then
    echo -e "${RED}  ✗ .env configuration has empty values${NC}"
    echo -e "${YELLOW}  KEYCLOAK_HOSTNAME_URL: $KEYCLOAK_HOSTNAME${NC}"
    echo -e "${YELLOW}  KEYCLOAK_PUBLIC_URL: $PUBLIC_KEYCLOAK${NC}"
    echo -e "${YELLOW}  Try running: ./scripts/setup-env.sh manually${NC}"
    exit 1
fi

if [ "$CONFIGURED_IP" = "unknown" ] || [ -z "$CONFIGURED_IP" ]; then
    echo -e "${RED}  ✗ Could not determine configured IP address${NC}"
    echo -e "${YELLOW}  Please check .env file${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ Configuration validated${NC}"
echo -e "${BLUE}  → Configured IP: ${BOLD}$CONFIGURED_IP${NC}"
echo -e "${BLUE}  → Keycloak URL: ${BOLD}$KEYCLOAK_HOSTNAME${NC}"
echo ""

##############################################################################
# Step 3: Start services with docker-compose
##############################################################################

echo -e "${YELLOW}[3/5] Starting services with Docker Compose...${NC}"

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}  ✗ docker-compose not found${NC}"
    echo -e "${YELLOW}  Please install Docker and Docker Compose${NC}"
    exit 1
fi

# Check if docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}  ✗ Docker daemon is not running${NC}"
    echo -e "${YELLOW}  Please start Docker first${NC}"
    exit 1
fi

# Start services
echo -e "${BLUE}  → Starting services (this may take a few minutes)...${NC}"
docker-compose up -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Services started successfully${NC}"
else
    echo -e "${RED}  ✗ Error: Failed to start services${NC}"
    echo -e "${YELLOW}  Check logs with: docker-compose logs${NC}"
    exit 1
fi

echo ""

##############################################################################
# Step 4: Wait for Keycloak to be accessible
##############################################################################

echo -e "${YELLOW}[4/5] Waiting for Keycloak to be ready...${NC}"

# Check if Keycloak is running
if ! docker-compose ps | grep -q "echograph-keycloak.*Up"; then
    echo -e "${RED}  ✗ Keycloak is not running${NC}"
    echo -e "${YELLOW}  Check logs: docker-compose logs keycloak${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ Keycloak container is running${NC}"

# Wait for Keycloak to be accessible
echo -e "${BLUE}  → Waiting for Keycloak to be accessible...${NC}"
echo -e "${YELLOW}  → Note: First startup can take 5-10 minutes (database initialization)${NC}"
MAX_WAIT=600  # 10 minutes (first start needs more time for DB schema init)
WAIT_COUNT=0
KEYCLOAK_READY=false

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|303"; then
        KEYCLOAK_READY=true
        break
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    if [ $((WAIT_COUNT % 20)) -eq 0 ]; then
        echo -e "${BLUE}  → Still waiting... (${WAIT_COUNT}s / ${MAX_WAIT}s)${NC}"
        # Show last log line to give user context
        LAST_LOG=$(docker-compose logs --tail=1 keycloak 2>/dev/null | grep -v "Attaching to")
        if [ -n "$LAST_LOG" ]; then
            echo -e "${YELLOW}     Latest: ${LAST_LOG:0:80}...${NC}"
        fi
    fi
done

if [ "$KEYCLOAK_READY" = false ]; then
    echo -e "${RED}  ✗ Keycloak did not become accessible within ${MAX_WAIT} seconds${NC}"
    echo -e "${YELLOW}  This might be normal on first startup. Check if still initializing:${NC}"
    echo -e "${YELLOW}  docker-compose logs -f keycloak${NC}"
    echo -e "${YELLOW}  Look for: 'Keycloak ... started' message${NC}"
    echo ""
    echo -e "${YELLOW}  Once Keycloak is ready, run: ./keycloak/init-keycloak.sh${NC}"
    # Don't exit - continue anyway, user can init Keycloak manually
fi

echo -e "${GREEN}  ✓ Keycloak is accessible (took ${WAIT_COUNT}s)${NC}"
echo ""

##############################################################################
# Step 5: Initialize Keycloak realm
##############################################################################

echo -e "${YELLOW}[5/5] Initializing Keycloak realm...${NC}"

# Check if realm already exists
REALM_EXISTS=$(curl -s http://localhost:8080/realms/echograph 2>&1 | grep -q "realm" && echo "true" || echo "false")

if [ "$REALM_EXISTS" = "true" ]; then
    echo -e "${GREEN}  ✓ Realm 'echograph' already exists${NC}"
else
    echo -e "${BLUE}  → Importing realm configuration...${NC}"

    if [ -f "$SCRIPT_DIR/keycloak/init-keycloak.sh" ]; then
        chmod +x "$SCRIPT_DIR/keycloak/init-keycloak.sh"

        # Run initialization
        "$SCRIPT_DIR/keycloak/init-keycloak.sh"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ Keycloak realm imported successfully${NC}"

            # Verify realm was imported
            sleep 2
            REALM_EXISTS=$(curl -s http://localhost:8080/realms/echograph 2>&1 | grep -q "realm" && echo "true" || echo "false")

            if [ "$REALM_EXISTS" = "true" ]; then
                echo -e "${GREEN}  ✓ Realm verified and accessible${NC}"
            else
                echo -e "${RED}  ✗ Realm import completed but realm not accessible${NC}"
                echo -e "${YELLOW}  Try running manually: ./keycloak/init-keycloak.sh${NC}"
            fi
        else
            echo -e "${RED}  ✗ Keycloak realm import failed${NC}"
            echo -e "${YELLOW}  Try running manually: ./keycloak/init-keycloak.sh${NC}"
        fi
    else
        echo -e "${RED}  ✗ Keycloak init script not found${NC}"
        exit 1
    fi
fi

# Restart frontend to ensure it picks up the configuration
echo -e "${BLUE}  → Restarting frontend with new configuration...${NC}"
docker-compose restart frontend > /dev/null 2>&1
echo -e "${GREEN}  ✓ Frontend restarted${NC}"

echo ""

##############################################################################
# Deployment Complete
##############################################################################

echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✓ Deployment Complete!${NC}"
echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════${NC}\n"

echo -e "${BOLD}Services are now available at:${NC}"
echo -e "  ${GREEN}Frontend:${NC}       http://${BOLD}$CONFIGURED_IP:3000${NC}"
echo -e "  ${GREEN}API:${NC}            http://${BOLD}$CONFIGURED_IP:8000${NC}"
echo -e "  ${GREEN}API Docs:${NC}       http://${BOLD}$CONFIGURED_IP:8000/docs${NC}"
echo -e "  ${GREEN}Keycloak:${NC}       http://${BOLD}$CONFIGURED_IP:8080${NC}"
echo -e "  ${GREEN}Keycloak Admin:${NC} http://${BOLD}$CONFIGURED_IP:8080/admin${NC}"
echo -e "  ${GREEN}n8n:${NC}            http://${BOLD}$CONFIGURED_IP:5678${NC}"
echo -e "  ${GREEN}MinIO Console:${NC}  http://${BOLD}$CONFIGURED_IP:9001${NC}"
echo -e ""

echo -e "${BOLD}Default Credentials:${NC}"
echo -e "  ${BLUE}Keycloak Admin:${NC}  admin / admin_changeme"
echo -e "  ${BLUE}EchoGraph User:${NC}   admin / admin (change on first login)"
echo -e "  ${BLUE}n8n:${NC}              admin / changeme"
echo -e "  ${BLUE}MinIO:${NC}            minioadmin / minioadmin"
echo -e ""

echo -e "${BOLD}Next Steps:${NC}"
echo -e "  1. Open ${BLUE}http://$CONFIGURED_IP:3000${NC} in your browser"
echo -e "  2. Click the ${BOLD}Login${NC} button"
echo -e "  3. Login with ${BLUE}admin / admin${NC}"
echo -e "  4. ${YELLOW}Change default passwords!${NC}"
echo -e ""

echo -e "${BOLD}Useful Commands:${NC}"
echo -e "  ${BLUE}Check status:${NC}    docker-compose ps"
echo -e "  ${BLUE}View logs:${NC}       docker-compose logs -f"
echo -e "  ${BLUE}Stop services:${NC}   docker-compose down"
echo -e "  ${BLUE}Restart:${NC}         docker-compose restart"
echo -e ""

echo -e "${YELLOW}⚠ SECURITY REMINDER:${NC}"
echo -e "  • Default passwords are in use - change them immediately!"
echo -e "  • For production, enable HTTPS and update security settings"
echo -e "  • Review ${BLUE}SECURITY.md${NC} for security best practices"
echo -e ""
