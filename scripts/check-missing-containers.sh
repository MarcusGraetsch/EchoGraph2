#!/bin/bash

# Check if we can run docker without sudo
if docker ps >/dev/null 2>&1; then
    DOCKER_CMD="docker"
    COMPOSE_CMD="docker compose"
elif sudo docker ps >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
    COMPOSE_CMD="sudo docker compose"
else
    echo "Error: Cannot access Docker"
    exit 1
fi

echo "=== Checking all containers ==="
$COMPOSE_CMD ps -a

echo ""
echo "=== Checking if API container exists ==="
$DOCKER_CMD ps -a | grep echograph-api

echo ""
echo "=== Checking if Frontend container exists ==="
$DOCKER_CMD ps -a | grep echograph-frontend

echo ""
echo "=== Checking if Celery container exists ==="
$DOCKER_CMD ps -a | grep echograph-celery

echo ""
echo "=== API container logs (all) ==="
$COMPOSE_CMD logs api 2>&1

echo ""
echo "=== Frontend container logs (all) ==="
$COMPOSE_CMD logs frontend 2>&1

echo ""
echo "=== Celery worker logs (all) ==="
$COMPOSE_CMD logs celery-worker 2>&1

echo ""
echo "=== Docker compose config check ==="
$COMPOSE_CMD config --services 2>&1
