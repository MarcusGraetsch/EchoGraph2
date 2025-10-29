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

echo "6. Checking Docker logs for errors..."
echo "Last 20 lines from each service:"
echo ""
echo "--- Frontend ---"
docker-compose logs --tail=20 frontend 2>/dev/null || sudo docker-compose logs --tail=20 frontend
echo ""
echo "--- API ---"
docker-compose logs --tail=20 api 2>/dev/null || sudo docker-compose logs --tail=20 api
echo ""

echo "=========================================="
echo "Diagnostics Complete"
echo "=========================================="
echo ""
echo "Common Issues & Fixes:"
echo ""
echo "1. Services not running:"
echo "   cd ~/EchoGraph2 && sudo docker-compose up -d"
echo ""
echo "2. Services crashed:"
echo "   cd ~/EchoGraph2 && sudo docker-compose restart"
echo ""
echo "3. Port binding issues:"
echo "   cd ~/EchoGraph2 && sudo docker-compose down && sudo docker-compose up -d"
echo ""
echo "4. View full logs:"
echo "   cd ~/EchoGraph2 && sudo docker-compose logs -f"
echo ""
