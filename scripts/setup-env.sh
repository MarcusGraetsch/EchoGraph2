#!/bin/bash

##############################################################################
# Environment Configuration Script for EchoGraph
##############################################################################
# This script generates the .env file from .env.example by:
# 1. Auto-detecting the VM's IP address
# 2. Replacing placeholder variables with actual values
# 3. Allowing manual IP override via command line argument
##############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  EchoGraph Environment Setup${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"

# Check if .env.example exists
if [ ! -f "$PROJECT_ROOT/.env.example" ]; then
    echo -e "${RED}ERROR: .env.example not found in $PROJECT_ROOT${NC}"
    exit 1
fi

# Detect or use provided IP
if [ -n "$1" ]; then
    # Manual IP provided as argument
    VM_IP="$1"
    echo -e "${GREEN}Using manually specified IP: $VM_IP${NC}\n"
else
    # Auto-detect IP
    echo -e "${YELLOW}Auto-detecting VM IP address...${NC}\n"
    if [ -x "$SCRIPT_DIR/detect-ip.sh" ]; then
        VM_IP=$("$SCRIPT_DIR/detect-ip.sh" | tail -n1)
    else
        echo -e "${RED}ERROR: detect-ip.sh not found or not executable${NC}"
        exit 1
    fi
fi

# Validate IP format
if ! echo "$VM_IP" | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' > /dev/null; then
    echo -e "${RED}ERROR: Invalid IP address format: $VM_IP${NC}"
    exit 1
fi

echo -e "\n${BLUE}Configuration:${NC}"
echo -e "  VM IP Address: ${GREEN}$VM_IP${NC}"
echo -e "  Project Root:  $PROJECT_ROOT"
echo -e ""

# Check if .env already exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${YELLOW}WARNING: .env file already exists!${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Aborted. Keeping existing .env file.${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Backing up existing .env to .env.backup${NC}"
    cp "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup"
fi

# Generate .env from .env.example
echo -e "${GREEN}Generating .env file...${NC}"

# Read .env.example and replace placeholders
cat "$PROJECT_ROOT/.env.example" | \
    sed "s/{{PUBLIC_IP}}/$VM_IP/g" | \
    sed "s/{{VM_IP}}/$VM_IP/g" \
    > "$PROJECT_ROOT/.env"

echo -e "${GREEN}✓ .env file created successfully!${NC}\n"

# Show summary
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Environment Configuration Complete${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e ""
echo -e "The following services will be accessible at:"
echo -e "  ${GREEN}Frontend:${NC}     http://$VM_IP:3000"
echo -e "  ${GREEN}API:${NC}          http://$VM_IP:8000"
echo -e "  ${GREEN}Keycloak:${NC}     http://$VM_IP:8080"
echo -e "  ${GREEN}n8n:${NC}          http://$VM_IP:5678"
echo -e "  ${GREEN}MinIO Console:${NC} http://$VM_IP:9001"
echo -e ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review the generated .env file: ${BLUE}cat .env${NC}"
echo -e "  2. Start services: ${BLUE}docker-compose up -d${NC}"
echo -e "  3. Initialize Keycloak: ${BLUE}./keycloak/init-keycloak.sh${NC}"
echo -e ""

# Show important security notes
echo -e "${YELLOW}⚠ SECURITY NOTES:${NC}"
echo -e "  • Default passwords are used - change them for production!"
echo -e "  • .env file contains secrets - never commit it to git"
echo -e "  • For production, enable HTTPS and update SSL settings"
echo -e ""
