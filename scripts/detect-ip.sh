#!/bin/bash

##############################################################################
# IP Address Detection Script for EchoGraph Deployment
##############################################################################
# This script detects the appropriate IP address for the VM where EchoGraph
# is deployed. It tries multiple methods to find the public/accessible IP.
##############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Detecting VM IP address...${NC}\n"

# Check if running in WSL2 or Docker Desktop environment
# For local development, use localhost
if grep -qi microsoft /proc/version 2>/dev/null || [ -f "/mnt/wsl/docker-desktop" ]; then
    echo -e "${YELLOW}WSL2 or Docker Desktop detected!${NC}"
    echo -e "${GREEN}Using localhost for local development${NC}\n"
    echo "localhost"
    exit 0
fi

# Method 1: Try to get public IPv4 from external service
echo "Method 1: Checking public IPv4 via external service..."
PUBLIC_IP=""
if command -v curl &> /dev/null; then
    # Try multiple services in case one is down - force IPv4 with -4 flag
    PUBLIC_IP=$(curl -4 -s --connect-timeout 3 ifconfig.me 2>/dev/null || \
                curl -4 -s --connect-timeout 3 icanhazip.com 2>/dev/null || \
                curl -4 -s --connect-timeout 3 api.ipify.org 2>/dev/null || \
                curl -4 -s --connect-timeout 3 ipv4.icanhazip.com 2>/dev/null || \
                echo "")

    # Validate it's IPv4 format
    if [ -n "$PUBLIC_IP" ] && echo "$PUBLIC_IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
        echo -e "${GREEN}✓ Public IPv4 detected: $PUBLIC_IP${NC}"
    else
        PUBLIC_IP=""
    fi
fi

# Method 2: Get primary network interface IPv4
echo -e "\nMethod 2: Checking primary network interface..."
INTERFACE_IP=""
if command -v hostname &> /dev/null; then
    # Get all IPs and filter for IPv4 only
    ALL_IPS=$(hostname -I 2>/dev/null || echo "")
    for ip in $ALL_IPS; do
        # Check if it's IPv4 format and not loopback
        if echo "$ip" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' && [ "$ip" != "127.0.0.1" ]; then
            INTERFACE_IP="$ip"
            echo -e "${GREEN}✓ Interface IPv4 detected: $INTERFACE_IP${NC}"
            break
        fi
    done
fi

# Method 3: Use ip command if available
echo -e "\nMethod 3: Checking via ip command..."
IP_CMD_IP=""
if command -v ip &> /dev/null; then
    # Get IP from default route interface (IPv4 only)
    DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -n "$DEFAULT_IFACE" ]; then
        # Get only IPv4 addresses (inet, not inet6)
        IP_CMD_IP=$(ip -4 addr show "$DEFAULT_IFACE" | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n1)
        if [ -n "$IP_CMD_IP" ]; then
            echo -e "${GREEN}✓ IPv4 from default interface ($DEFAULT_IFACE): $IP_CMD_IP${NC}"
        fi
    fi
fi

# Determine which IP to use (prefer public, then interface, then ip command)
DETECTED_IP=""

if [ -n "$PUBLIC_IP" ]; then
    DETECTED_IP="$PUBLIC_IP"
    echo -e "\n${GREEN}Using public IPv4: $DETECTED_IP${NC}"
elif [ -n "$INTERFACE_IP" ]; then
    DETECTED_IP="$INTERFACE_IP"
    echo -e "\n${YELLOW}Using interface IPv4: $DETECTED_IP${NC}"
    echo -e "${YELLOW}Note: This might be a private IP. If accessing from outside the network, you may need the public IP.${NC}"
elif [ -n "$IP_CMD_IP" ]; then
    DETECTED_IP="$IP_CMD_IP"
    echo -e "\n${YELLOW}Using IPv4 from default interface: $DETECTED_IP${NC}"
else
    echo -e "\n${RED}ERROR: Could not detect IPv4 address!${NC}"
    echo -e "${YELLOW}This system may only have IPv6 addresses.${NC}"
    echo -e "${YELLOW}Please manually specify an IPv4 address: ./scripts/setup-env.sh YOUR_IPV4_ADDRESS${NC}"
    exit 1
fi

# Validate IPv4 format (final check)
if ! echo "$DETECTED_IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    echo -e "${RED}ERROR: Detected IP '$DETECTED_IP' is not in valid IPv4 format!${NC}"
    echo -e "${YELLOW}Please manually specify an IPv4 address: ./scripts/setup-env.sh YOUR_IPV4_ADDRESS${NC}"
    exit 1
fi

# Output the IP (this is used by other scripts)
echo "$DETECTED_IP"
