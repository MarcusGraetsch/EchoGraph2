#!/bin/bash

##############################################################################
# Quick Fix for Keycloak 404 Error
##############################################################################
# This script fixes the "404 Not Found" error when trying to login
##############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Keycloak 404 Error Fix${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

##############################################################################
# Step 1: Check if Keycloak is running
##############################################################################

echo -e "${YELLOW}[1/5] Checking if Keycloak is running...${NC}"

if ! docker ps | grep -q echograph-keycloak; then
    echo -e "${RED}✗ Keycloak is not running!${NC}"
    echo -e "${BLUE}Starting Keycloak...${NC}"
    docker-compose up -d keycloak
    echo -e "${YELLOW}Waiting 60 seconds for Keycloak to start...${NC}"
    sleep 60
else
    echo -e "${GREEN}✓ Keycloak is running${NC}"
fi
echo ""

##############################################################################
# Step 2: Check if realm exists
##############################################################################

echo -e "${YELLOW}[2/5] Checking if realm exists...${NC}"

# Wait for Keycloak to be accessible
MAX_TRIES=30
COUNT=0
while [ $COUNT -lt $MAX_TRIES ]; do
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Keycloak is accessible${NC}"
        break
    fi
    COUNT=$((COUNT+1))
    if [ $COUNT -eq $MAX_TRIES ]; then
        echo -e "${RED}✗ Keycloak is not accessible after waiting${NC}"
        echo -e "${YELLOW}Check logs: docker-compose logs keycloak${NC}"
        exit 1
    fi
    sleep 2
done

# Check if realm exists
REALM_CHECK=$(curl -s http://localhost:8080/realms/echograph 2>&1)

if echo "$REALM_CHECK" | grep -q "realm"; then
    echo -e "${GREEN}✓ Realm 'echograph' already exists${NC}"
    REALM_EXISTS=true
else
    echo -e "${YELLOW}⚠ Realm 'echograph' not found - will import it${NC}"
    REALM_EXISTS=false
fi
echo ""

##############################################################################
# Step 3: Import realm if needed
##############################################################################

if [ "$REALM_EXISTS" = false ]; then
    echo -e "${YELLOW}[3/5] Importing Keycloak realm...${NC}"

    if [ -f "./keycloak/init-keycloak.sh" ]; then
        chmod +x ./keycloak/init-keycloak.sh
        ./keycloak/init-keycloak.sh

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Realm imported successfully${NC}"
        else
            echo -e "${RED}✗ Failed to import realm${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ init-keycloak.sh not found!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}[3/5] Realm exists, skipping import${NC}"
fi
echo ""

##############################################################################
# Step 4: Verify realm is accessible
##############################################################################

echo -e "${YELLOW}[4/5] Verifying realm is accessible...${NC}"

# Get configured IP
if [ -f .env ]; then
    CONFIGURED_IP=$(grep -E "^KEYCLOAK_HOSTNAME_URL=" .env | cut -d'/' -f3 | cut -d':' -f1)
else
    CONFIGURED_IP="localhost"
fi

# Test realm endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${CONFIGURED_IP}:8080/realms/echograph 2>&1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Realm is accessible (HTTP 200)${NC}"
else
    echo -e "${RED}✗ Realm returned HTTP $HTTP_CODE${NC}"
    echo -e "${YELLOW}This might be a hostname configuration issue${NC}"
fi
echo ""

##############################################################################
# Step 5: Restart frontend to pick up changes
##############################################################################

echo -e "${YELLOW}[5/5] Restarting frontend...${NC}"
docker-compose restart frontend

echo -e "${GREEN}✓ Frontend restarted${NC}"
echo ""

##############################################################################
# Complete
##############################################################################

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Fix Applied!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Open browser to: ${BLUE}http://${CONFIGURED_IP}:3000${NC}"
echo -e "  2. Click the ${BLUE}Login${NC} button"
echo -e "  3. You should see the Keycloak login page"
echo -e "  4. Login with: ${BLUE}admin / admin${NC}"
echo ""

echo -e "${YELLOW}If still getting 404:${NC}"
echo -e "  • Check Keycloak logs: ${BLUE}docker-compose logs keycloak${NC}"
echo -e "  • Run diagnostics: ${BLUE}./scripts/diagnose.sh${NC}"
echo -e "  • Try rebuilding frontend: ${BLUE}docker-compose up -d --build frontend${NC}"
echo ""
