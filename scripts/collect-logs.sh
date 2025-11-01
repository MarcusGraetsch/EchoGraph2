#!/bin/bash
# Log collection script for debugging failed services

# Check if we can run docker without sudo
if docker ps >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif sudo docker ps >/dev/null 2>&1; then
    COMPOSE_CMD="sudo docker compose"
else
    echo "Error: Cannot access Docker (tried with and without sudo)"
    exit 1
fi

echo "Collecting logs from failed services..."
echo "Using: $COMPOSE_CMD"
echo ""

echo "=================================================="
echo "KEYCLOAK LOGS (last 100 lines)"
echo "=================================================="
$COMPOSE_CMD logs keycloak --tail=100 2>&1
echo ""

echo "=================================================="
echo "API LOGS (last 100 lines)"
echo "=================================================="
$COMPOSE_CMD logs api --tail=100 2>&1
echo ""

echo "=================================================="
echo "FRONTEND LOGS (last 50 lines)"
echo "=================================================="
$COMPOSE_CMD logs frontend --tail=50 2>&1
echo ""

echo "=================================================="
echo "CELERY WORKER LOGS (last 50 lines)"
echo "=================================================="
$COMPOSE_CMD logs celery-worker --tail=50 2>&1
echo ""

echo "=================================================="
echo "POSTGRES LOGS (last 50 lines)"
echo "=================================================="
$COMPOSE_CMD logs postgres --tail=50 2>&1
echo ""

echo "=================================================="
echo "CONTAINER STATUS"
echo "=================================================="
$COMPOSE_CMD ps 2>&1
