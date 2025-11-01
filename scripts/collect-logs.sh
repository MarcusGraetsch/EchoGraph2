#!/bin/bash
# Log collection script for debugging failed services

echo "Collecting logs from failed services..."
echo ""

echo "=================================================="
echo "KEYCLOAK LOGS (last 100 lines)"
echo "=================================================="
docker compose logs keycloak --tail=100
echo ""

echo "=================================================="
echo "API LOGS (last 100 lines)"
echo "=================================================="
docker compose logs api --tail=100
echo ""

echo "=================================================="
echo "FRONTEND LOGS (last 50 lines)"
echo "=================================================="
docker compose logs frontend --tail=50
echo ""

echo "=================================================="
echo "CELERY WORKER LOGS (last 50 lines)"
echo "=================================================="
docker compose logs celery-worker --tail=50
echo ""

echo "=================================================="
echo "CONTAINER STATUS"
echo "=================================================="
docker compose ps
