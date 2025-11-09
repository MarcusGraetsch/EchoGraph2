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

# Method 1: Try to get public IP from external service
echo "Method 1: Checking public IP via external service..."
PUBLIC_IP=""
if command -v curl &> /dev/null; then
    # Try multiple services in case one is down
    PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me || \
                curl -s --connect-timeout 3 icanhazip.com || \
                curl -s --connect-timeout 3 api.ipify.org || \
                echo "")

    if [ -n "$PUBLIC_IP" ]; then
        echo -e "${GREEN}✓ Public IP detected: $PUBLIC_IP${NC}"
    fi
fi

# Method 2: Get primary network interface IP
echo -e "\nMethod 2: Checking primary network interface..."
INTERFACE_IP=""
if command -v hostname &> /dev/null; then
    # Get the first non-loopback IP
    INTERFACE_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")

    if [ -n "$INTERFACE_IP" ] && [ "$INTERFACE_IP" != "127.0.0.1" ]; then
        echo -e "${GREEN}✓ Interface IP detected: $INTERFACE_IP${NC}"
    fi
fi

# Method 3: Use ip command if available
echo -e "\nMethod 3: Checking via ip command..."
IP_CMD_IP=""
if command -v ip &> /dev/null; then
    # Get IP from default route interface
    DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -n "$DEFAULT_IFACE" ]; then
        IP_CMD_IP=$(ip addr show "$DEFAULT_IFACE" | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n1)
        if [ -n "$IP_CMD_IP" ]; then
            echo -e "${GREEN}✓ IP from default interface ($DEFAULT_IFACE): $IP_CMD_IP${NC}"
        fi
    fi
fi

# Determine which IP to use (prefer public, then interface, then ip command)
DETECTED_IP=""

if [ -n "$PUBLIC_IP" ]; then
    DETECTED_IP="$PUBLIC_IP"
    echo -e "\n${GREEN}Using public IP: $DETECTED_IP${NC}"
elif [ -n "$INTERFACE_IP" ]; then
    DETECTED_IP="$INTERFACE_IP"
    echo -e "\n${YELLOW}Using interface IP: $DETECTED_IP${NC}"
    echo -e "${YELLOW}Note: This might be a private IP. If accessing from outside the network, you may need the public IP.${NC}"
elif [ -n "$IP_CMD_IP" ]; then
    DETECTED_IP="$IP_CMD_IP"
    echo -e "\n${YELLOW}Using IP from default interface: $DETECTED_IP${NC}"
else
    echo -e "\n${RED}ERROR: Could not detect IP address!${NC}"
    echo -e "${YELLOW}Please set the IP manually in .env file.${NC}"
    exit 1
fi

# Validate IP format
if ! echo "$DETECTED_IP" | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' > /dev/null; then
    echo -e "${RED}ERROR: Detected IP '$DETECTED_IP' is not in valid format!${NC}"
    exit 1
fi

# Output the IP (this is used by other scripts)
echo "$DETECTED_IP"
