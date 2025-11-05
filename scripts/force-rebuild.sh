#!/bin/bash
# Emergency script to force complete rebuild with latest code

set -e

echo "=========================================="
echo "EMERGENCY FIX: Force Rebuild with Latest Code"
echo "=========================================="
echo ""

# Get to repo directory
cd "$(dirname "$0")/.."

# Pull absolute latest code
echo "1. Pulling latest code from git..."
git fetch origin
git pull origin $(git branch --show-current) || git pull origin main

echo ""
echo "2. Stopping all containers..."
sudo docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
sudo docker-compose down 2>/dev/null || true

echo ""
echo "3. Removing old Docker images..."
sudo docker rmi echograph2-api echograph2-celery-worker echograph2-frontend 2>/dev/null || true

echo ""
echo "4. Building fresh images with --no-cache..."
if [ -f "docker-compose.prod.yml" ]; then
    echo "   Using docker-compose.prod.yml (production mode)"
    sudo docker-compose -f docker-compose.prod.yml build --no-cache --pull api celery-worker frontend
    echo ""
    echo "5. Starting containers..."
    sudo docker-compose -f docker-compose.prod.yml up -d
else
    echo "   WARNING: docker-compose.prod.yml not found, using docker-compose.yml"
    sudo docker-compose build --no-cache --pull api celery-worker frontend
    echo ""
    echo "5. Starting containers..."
    sudo docker-compose up -d
fi

echo ""
echo "6. Waiting for containers to start..."
sleep 10

echo ""
echo "7. Checking API logs..."
sudo docker logs echograph-api --tail 50

echo ""
echo "=========================================="
echo "DONE! Check logs above for any errors."
echo "=========================================="
