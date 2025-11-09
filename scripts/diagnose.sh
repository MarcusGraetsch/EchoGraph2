#!/bin/bash
# EchoGraph Diagnostics Script
# Run this to diagnose connection issues

echo "=========================================="
echo "EchoGraph Connection Diagnostics"
echo "=========================================="
echo ""

# Check if running from EchoGraph directory
if [ ! -f "docker-compose.yml" ]; then
    echo "ERROR: Please run this from the EchoGraph2 directory"
    echo "cd ~/EchoGraph2 && ./scripts/diagnose.sh"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "1. Checking Docker service..."
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker is running${NC}"
else
    echo -e "${RED}✗ Docker is NOT running${NC}"
    echo "Fix: sudo systemctl start docker"
fi
echo ""

echo "2. Checking Docker Compose services..."
docker-compose ps 2>/dev/null || sudo docker-compose ps
echo ""

echo "3. Checking if ports are listening..."
echo "Expected: Docker processes listening on 0.0.0.0:PORT"
sudo netstat -tlnp | grep -E '(3000|8000|5678|9000|9001)' || echo "No services listening on expected ports!"
echo ""

echo "4. Testing local connectivity..."
if curl -s http://localhost:3000 > /dev/null; then
    echo -e "${GREEN}✓ Frontend responds on localhost${NC}"
else
    echo -e "${RED}✗ Frontend NOT responding on localhost${NC}"
fi

if curl -s http://localhost:8000/health > /dev/null; then
    echo -e "${GREEN}✓ API responds on localhost${NC}"
else
    echo -e "${RED}✗ API NOT responding on localhost${NC}"
fi
echo ""

echo "5. Checking firewall rules..."
sudo ufw status | grep -E '(3000|8000|5678|9000|9001)'
echo ""

echo "6. Checking Keycloak status..."
if curl -s http://localhost:8080 > /dev/null; then
    echo -e "${GREEN}✓ Keycloak responds on localhost${NC}"

    # Check if realm exists
    REALM_CHECK=$(curl -s http://localhost:8080/realms/echograph 2>&1)
    if echo "$REALM_CHECK" | grep -q "realm"; then
        echo -e "${GREEN}✓ Realm 'echograph' exists${NC}"
    else
        echo -e "${RED}✗ Realm 'echograph' NOT found!${NC}"
        echo -e "${YELLOW}You need to import the realm: ./keycloak/init-keycloak.sh${NC}"
    fi
else
    echo -e "${RED}✗ Keycloak NOT responding on localhost${NC}"
fi
echo ""

echo "7. Checking environment configuration..."
if [ -f .env ]; then
    echo -e "${GREEN}✓ .env file exists${NC}"
    echo "Keycloak Hostname: $(grep KEYCLOAK_HOSTNAME_URL .env | cut -d'=' -f2)"
    echo "Frontend Keycloak URL: $(grep NEXT_PUBLIC_KEYCLOAK_URL .env | cut -d'=' -f2)"
else
    echo -e "${RED}✗ .env file NOT found!${NC}"
    echo -e "${YELLOW}Run: ./scripts/setup-env.sh${NC}"
fi
echo ""

echo "8. Checking Docker logs for errors..."
echo "Last 30 lines from Keycloak:"
echo ""
echo "--- Keycloak ---"
docker-compose logs --tail=30 keycloak 2>/dev/null || sudo docker-compose logs --tail=30 keycloak
echo ""
echo "--- Frontend ---"
docker-compose logs --tail=20 frontend 2>/dev/null || sudo docker-compose logs --tail=20 frontend
echo ""

echo "=========================================="
echo "Diagnostics Complete"
echo "=========================================="
echo ""
echo "Common Issues & Fixes:"
echo ""
echo "1. Keycloak realm not found (404 error):"
echo "   ./keycloak/init-keycloak.sh"
echo ""
echo "2. Missing .env configuration:"
echo "   ./scripts/setup-env.sh"
echo ""
echo "3. Services not running:"
echo "   cd ~/EchoGraph2 && sudo docker-compose up -d"
echo ""
echo "4. Services crashed:"
echo "   cd ~/EchoGraph2 && sudo docker-compose restart keycloak frontend"
echo ""
echo "5. Port binding issues:"
echo "   cd ~/EchoGraph2 && sudo docker-compose down && sudo docker-compose up -d"
echo ""
echo "6. View full Keycloak logs:"
echo "   cd ~/EchoGraph2 && sudo docker-compose logs -f keycloak"
echo ""
