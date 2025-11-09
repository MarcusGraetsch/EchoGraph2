#!/bin/bash

##############################################################################
# Quick Deploy Script - Apply Keycloak Authentication Fix
##############################################################################
# This script applies the authentication fix on your VM.
# Run this on the VM at 178.18.254.21
##############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  EchoGraph - Keycloak Authentication Fix${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo -e "${YELLOW}Step 1/5: Pulling latest changes from repository...${NC}"
git fetch origin
git pull origin claude/fix-keycloak-auth-redirect-011CUxdt2HfSS3shts5DPrgP
echo -e "${GREEN}✓ Repository updated${NC}\n"

echo -e "${YELLOW}Step 2/5: Generating .env configuration...${NC}"
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${YELLOW}Backing up existing .env to .env.backup${NC}"
    cp "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup"
fi
"$PROJECT_ROOT/scripts/setup-env.sh"
echo -e "${GREEN}✓ Configuration generated${NC}\n"

echo -e "${YELLOW}Step 3/5: Stopping services...${NC}"
docker-compose down
echo -e "${GREEN}✓ Services stopped${NC}\n"

echo -e "${YELLOW}Step 4/5: Starting services with new configuration...${NC}"
docker-compose up -d
echo -e "${GREEN}✓ Services starting...${NC}\n"

echo -e "${YELLOW}Waiting for services to start (60 seconds)...${NC}"
sleep 60

echo -e "${YELLOW}Step 5/5: Initializing Keycloak...${NC}"
if [ -f "$PROJECT_ROOT/keycloak/init-keycloak.sh" ]; then
    "$PROJECT_ROOT/keycloak/init-keycloak.sh"
else
    echo -e "${RED}ERROR: init-keycloak.sh not found${NC}"
    echo -e "${YELLOW}Please run manually: ./keycloak/init-keycloak.sh${NC}"
fi

echo -e "\n${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

# Get the configured IP
CONFIGURED_IP=$(grep KEYCLOAK_HOSTNAME_URL .env | cut -d'/' -f3 | cut -d':' -f1)

echo -e "Services are now available at:"
echo -e "  ${GREEN}Frontend:${NC}     http://$CONFIGURED_IP:3000"
echo -e "  ${GREEN}API:${NC}          http://$CONFIGURED_IP:8000"
echo -e "  ${GREEN}Keycloak:${NC}     http://$CONFIGURED_IP:8080"
echo -e ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Open browser to: ${BLUE}http://$CONFIGURED_IP:3000${NC}"
echo -e "  2. Click the 'Login' button"
echo -e "  3. You should see the Keycloak login page"
echo -e "  4. Login with: ${BLUE}admin / admin${NC} (change on first login)"
echo -e ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo -e "  • Check logs: ${BLUE}docker-compose logs -f keycloak${NC}"
echo -e "  • Check status: ${BLUE}docker-compose ps${NC}"
echo -e ""
