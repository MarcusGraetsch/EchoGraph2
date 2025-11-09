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

echo -e "${YELLOW}[1/4] Checking environment configuration...${NC}"

NEEDS_ENV_GENERATION=false

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}  ⚠ .env file not found${NC}"
    NEEDS_ENV_GENERATION=true
elif grep -q "{{PUBLIC_IP}}" "$SCRIPT_DIR/.env" 2>/dev/null; then
    echo -e "${YELLOW}  ⚠ .env file contains placeholders${NC}"
    NEEDS_ENV_GENERATION=true
else
    echo -e "${GREEN}  ✓ .env file exists and is configured${NC}"
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

    # Run setup-env.sh automatically
    "$SCRIPT_DIR/scripts/setup-env.sh"

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

echo -e "${YELLOW}[2/4] Validating configuration...${NC}"

# Check if .env exists now
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${RED}  ✗ .env file still missing after generation${NC}"
    exit 1
fi

# Extract configured IP
CONFIGURED_IP=$(grep -E "^KEYCLOAK_HOSTNAME_URL=" .env | cut -d'/' -f3 | cut -d':' -f1 || echo "unknown")

if [ "$CONFIGURED_IP" = "unknown" ] || [ -z "$CONFIGURED_IP" ]; then
    echo -e "${RED}  ✗ Could not determine configured IP address${NC}"
    echo -e "${YELLOW}  Please check .env file${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ Configuration validated${NC}"
echo -e "${BLUE}  → Configured IP: ${BOLD}$CONFIGURED_IP${NC}"
echo ""

##############################################################################
# Step 3: Start services with docker-compose
##############################################################################

echo -e "${YELLOW}[3/4] Starting services with Docker Compose...${NC}"

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
# Step 4: Wait for services and initialize Keycloak
##############################################################################

echo -e "${YELLOW}[4/4] Waiting for services to be ready...${NC}"

# Wait for services to start
echo -e "${BLUE}  → Waiting 60 seconds for services to initialize...${NC}"
sleep 60

# Check if Keycloak is running
if docker-compose ps | grep -q "echograph-keycloak.*Up"; then
    echo -e "${GREEN}  ✓ Keycloak is running${NC}"

    # Initialize Keycloak
    echo -e "${BLUE}  → Initializing Keycloak...${NC}"

    if [ -f "$SCRIPT_DIR/keycloak/init-keycloak.sh" ]; then
        chmod +x "$SCRIPT_DIR/keycloak/init-keycloak.sh"

        # Run initialization
        "$SCRIPT_DIR/keycloak/init-keycloak.sh"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ Keycloak initialized successfully${NC}"
        else
            echo -e "${YELLOW}  ⚠ Keycloak initialization had issues${NC}"
            echo -e "${YELLOW}  You may need to run: ./keycloak/init-keycloak.sh${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ Keycloak init script not found${NC}"
        echo -e "${YELLOW}  Please run: ./keycloak/init-keycloak.sh${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ Keycloak may still be starting${NC}"
    echo -e "${YELLOW}  Monitor with: docker-compose logs -f keycloak${NC}"
fi

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
