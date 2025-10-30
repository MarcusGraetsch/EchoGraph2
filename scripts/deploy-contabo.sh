#!/bin/bash

# EchoGraph Deployment Script for Contabo/Ubuntu VMs
# This script automates the deployment process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root!"
    echo ""
    echo "To fix this, create a non-root user:"
    echo ""
    echo "  1. Create user:     adduser echograph"
    echo "  2. Add sudo rights: usermod -aG sudo echograph"
    echo "  3. Switch user:     su - echograph"
    echo "  4. Re-run script:   cd ~/EchoGraph2 && ./scripts/deploy-contabo.sh"
    echo ""
    exit 1
fi

print_header "EchoGraph Deployment Script"
echo "This script will set up EchoGraph on your Ubuntu server."
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Step 1: Update System
print_header "Step 1: Updating System"
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget git vim ufw
print_success "System updated"

# Step 2: Configure Firewall
print_header "Step 2: Configuring Firewall"
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 8000/tcp
sudo ufw allow 5678/tcp
sudo ufw allow 9000/tcp
sudo ufw allow 9001/tcp
sudo ufw --force enable
print_success "Firewall configured"
echo ""
print_warning "IMPORTANT: If using Contabo, also configure firewall in Contabo Control Panel!"
echo "Add rules for ports: 22, 80, 443, 3000, 8000, 5678, 9000, 9001"
echo ""
read -p "Press Enter to continue..."

# Step 3: Install Docker
print_header "Step 3: Installing Docker"
if ! command -v docker &> /dev/null; then
    # Install Docker dependencies
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io

    # Add user to docker group
    sudo usermod -aG docker $USER

    print_success "Docker installed"
else
    print_success "Docker already installed"
fi

# Step 4: Install Docker Compose
print_header "Step 4: Installing Docker Compose"
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installed"
else
    print_success "Docker Compose already installed"
fi

# Step 5: Clone Repository
print_header "Step 5: Cloning EchoGraph Repository"
if [ -d "EchoGraph2" ]; then
    print_warning "EchoGraph2 directory already exists"
    read -p "Remove and re-clone? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf EchoGraph2
        git clone https://github.com/MarcusGraetsch/EchoGraph2.git
        print_success "Repository cloned"
    fi
else
    git clone https://github.com/MarcusGraetsch/EchoGraph2.git
    print_success "Repository cloned"
fi

cd EchoGraph2

# Step 6: Configure Environment
print_header "Step 6: Configuring Environment"
if [ ! -f ".env" ]; then
    # Generate random secrets
    API_SECRET=$(openssl rand -hex 32)
    POSTGRES_PASSWORD=$(openssl rand -base64 24)
    MINIO_SECRET=$(openssl rand -hex 32)
    N8N_PASSWORD=$(openssl rand -base64 16)

    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me)

    # Create comprehensive .env file
    cat > .env << EOF
# Database Configuration
POSTGRES_USER=echograph
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=echograph
DATABASE_URL=postgresql://echograph:$POSTGRES_PASSWORD@postgres:5432/echograph

# MinIO / S3 Configuration
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=$MINIO_SECRET
MINIO_BUCKET=echograph-documents
MINIO_USE_SSL=false

# API Configuration
API_HOST=http://$SERVER_IP:8000
API_PORT=8000
API_SECRET_KEY=$API_SECRET
API_ALGORITHM=HS256
API_ACCESS_TOKEN_EXPIRE_MINUTES=30

# Frontend Configuration
WS_HOST=ws://$SERVER_IP:8000
NEXT_PUBLIC_API_URL=http://$SERVER_IP:8000
NEXT_PUBLIC_WS_URL=ws://$SERVER_IP:8000

# n8n Configuration
N8N_HOST=$SERVER_IP
N8N_PORT=5678
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD

# Redis / Celery Configuration
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# Vector Store (Qdrant)
QDRANT_HOST=qdrant
QDRANT_PORT=6333

# AI/ML Configuration
EMBEDDING_MODEL=sentence-transformers/multi-qa-mpnet-base-dot-v1
EMBEDDING_DIMENSION=768
USE_GPU=false

# Document Processing
MAX_UPLOAD_SIZE_MB=100
CHUNK_SIZE=512
CHUNK_OVERLAP=50
OCR_ENABLED=true

# Monitoring
LOG_LEVEL=INFO
ENABLE_METRICS=true

# Security
ALLOWED_ORIGINS=http://$SERVER_IP:3000,http://$SERVER_IP:8000
CORS_ALLOW_CREDENTIALS=true
EOF

    print_success "Environment configured with random secure passwords"
    echo ""
    echo "Generated Credentials:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  PostgreSQL Password: $POSTGRES_PASSWORD"
    echo "  MinIO Secret Key:    $MINIO_SECRET"
    echo "  n8n Username:        admin"
    echo "  n8n Password:        $N8N_PASSWORD"
    echo "  API Secret Key:      $API_SECRET"
    echo "  Server IP:           $SERVER_IP"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_warning "IMPORTANT: Save these credentials securely!"
    echo ""

    # Ask if user wants to change passwords now
    print_header "Password Management"
    echo "You have two options for password security:"
    echo ""
    echo "  1. Change passwords NOW (recommended for production)"
    echo "  2. Change passwords LATER (faster setup, less secure)"
    echo ""
    read -p "Do you want to change passwords now? (y/n) " -n 1 -r
    echo
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Changing passwords interactively..."
        echo ""

        # PostgreSQL Password
        read -sp "Enter new PostgreSQL password (or press Enter to keep generated): " NEW_POSTGRES_PASSWORD
        echo
        if [ -n "$NEW_POSTGRES_PASSWORD" ]; then
            POSTGRES_PASSWORD=$NEW_POSTGRES_PASSWORD
            sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|g" .env
            sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://echograph:$POSTGRES_PASSWORD@postgres:5432/echograph|g" .env
            print_success "PostgreSQL password updated"
        else
            print_info "Keeping generated PostgreSQL password"
        fi
        echo ""

        # n8n Password
        read -sp "Enter new n8n password (or press Enter to keep generated): " NEW_N8N_PASSWORD
        echo
        if [ -n "$NEW_N8N_PASSWORD" ]; then
            N8N_PASSWORD=$NEW_N8N_PASSWORD
            sed -i "s|N8N_BASIC_AUTH_PASSWORD=.*|N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD|g" .env
            print_success "n8n password updated"
        else
            print_info "Keeping generated n8n password"
        fi
        echo ""

        # MinIO Secret
        read -sp "Enter new MinIO secret key (or press Enter to keep generated): " NEW_MINIO_SECRET
        echo
        if [ -n "$NEW_MINIO_SECRET" ]; then
            MINIO_SECRET=$NEW_MINIO_SECRET
            sed -i "s|MINIO_SECRET_KEY=.*|MINIO_SECRET_KEY=$MINIO_SECRET|g" .env
            print_success "MinIO secret key updated"
        else
            print_info "Keeping generated MinIO secret"
        fi
        echo ""

        print_success "Password configuration complete!"
    else
        print_warning "Passwords can be changed later by editing the .env file"
        echo ""
        echo "To change passwords later:"
        echo "  1. Edit file: nano ~/EchoGraph2/.env"
        echo "  2. Update these variables:"
        echo "     - POSTGRES_PASSWORD"
        echo "     - DATABASE_URL (update password in connection string)"
        echo "     - N8N_BASIC_AUTH_PASSWORD"
        echo "     - MINIO_SECRET_KEY"
        echo "     - API_SECRET_KEY"
        echo "  3. Restart services: cd ~/EchoGraph2 && sudo docker-compose restart"
        echo ""
        read -p "Press Enter to continue with deployment..."
    fi
else
    print_warning ".env file already exists, skipping"
    SERVER_IP=$(grep "NEXT_PUBLIC_API_URL" .env | cut -d'/' -f3 | cut -d':' -f1 || curl -s ifconfig.me)
fi

# Step 7: Create Data Directories
print_header "Step 7: Creating Data Directories"
mkdir -p data/raw data/processed
chmod 755 data/raw data/processed
print_success "Data directories created"

# Step 8: Start Services
print_header "Step 8: Starting Docker Services"

# Check if we can run docker without sudo
if docker ps >/dev/null 2>&1; then
    print_success "Docker permissions OK"
    DOCKER_CMD="docker"
    COMPOSE_CMD="docker-compose"
else
    print_warning "Docker group changes not yet active, using sudo for this session"
    DOCKER_CMD="sudo docker"
    COMPOSE_CMD="sudo docker-compose"
fi

# Stop any existing services
$COMPOSE_CMD down 2>/dev/null || true

# Start services
print_info "Starting Docker containers..."
if $COMPOSE_CMD up -d 2>&1 | grep -v "attribute.*version.*obsolete"; then
    print_success "Docker Compose started"
else
    print_error "Failed to start services"
    echo ""
    echo "To fix this:"
    echo "  1. Log out and log back in (for Docker group to take effect)"
    echo "  2. Or run: newgrp docker"
    echo "  3. Then run: cd ~/EchoGraph2 && docker-compose up -d"
    echo ""
    exit 1
fi

# Step 9: Health Check Services
print_header "Step 9: Health Check - Verifying All Services"
echo "Waiting for services to initialize..."
sleep 10

# Function to check service health
check_service() {
    local service=$1
    local max_attempts=12
    local wait_time=5
    local attempt=1

    print_info "Checking $service..."

    while [ $attempt -le $max_attempts ]; do
        local status=$($COMPOSE_CMD ps --format json $service 2>/dev/null | grep -o '"Health":"[^"]*"' | cut -d'"' -f4 || echo "")
        local state=$($COMPOSE_CMD ps --format json $service 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4 || echo "")

        if [ "$state" = "running" ]; then
            if [ -z "$status" ] || [ "$status" = "healthy" ] || [ "$status" = "" ]; then
                print_success "$service is running"
                return 0
            fi
        fi

        if [ $attempt -eq $max_attempts ]; then
            print_error "$service failed to start properly"
            return 1
        fi

        echo "  Attempt $attempt/$max_attempts - waiting ${wait_time}s..."
        sleep $wait_time
        ((attempt++))
    done

    return 1
}

# Check each service
services_ok=true

echo ""
echo "Checking core services:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_service "postgres" || services_ok=false
check_service "redis" || services_ok=false
check_service "minio" || services_ok=false
check_service "qdrant" || services_ok=false
check_service "n8n" || services_ok=false

echo ""
echo "Checking application services:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_service "api" || services_ok=false
check_service "frontend" || services_ok=false
check_service "celery-worker" || services_ok=false

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# If services failed, try to fix them
if [ "$services_ok" = false ]; then
    print_warning "Some services failed health checks. Attempting to fix..."
    echo ""

    # Show logs for failed services
    print_info "Checking logs for errors..."
    echo ""

    # Check API logs for common issues
    api_logs=$($COMPOSE_CMD logs --tail=20 api 2>&1)
    if echo "$api_logs" | grep -q "password authentication failed"; then
        print_error "Database authentication error detected"
        echo "  Issue: API cannot connect to PostgreSQL with current password"
        echo "  Fix: Restarting database and API services..."
        $COMPOSE_CMD restart postgres
        sleep 5
        $COMPOSE_CMD restart api
        sleep 10
    elif echo "$api_logs" | grep -q "Connection refused"; then
        print_error "Service connection error detected"
        echo "  Issue: API cannot reach dependent services"
        echo "  Fix: Restarting all services in correct order..."
        $COMPOSE_CMD restart postgres redis minio qdrant
        sleep 10
        $COMPOSE_CMD restart api celery-worker frontend
        sleep 10
    fi

    # Re-check services after fix attempt
    print_info "Re-checking services after fix attempt..."
    sleep 5

    services_ok=true
    check_service "api" || services_ok=false
    check_service "frontend" || services_ok=false

    if [ "$services_ok" = false ]; then
        print_error "Services still failing after fix attempt"
        echo ""
        echo "Manual intervention required. Check logs with:"
        echo "  ${COMPOSE_CMD} logs api"
        echo "  ${COMPOSE_CMD} logs frontend"
        echo "  ${COMPOSE_CMD} logs postgres"
        echo ""
        echo "Common issues:"
        echo "  1. Database password mismatch - check .env file"
        echo "  2. Port conflicts - check if ports 3000, 8000, 5432 are available"
        echo "  3. Resource limits - ensure enough RAM/CPU available"
        echo ""
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "All services recovered successfully!"
    fi
fi

# Step 10: Test API Endpoint
print_header "Step 10: Testing API Endpoints"
sleep 5

# Test API health endpoint
print_info "Testing API health endpoint..."
api_response=$(curl -s http://localhost:8000/health || echo "failed")
if echo "$api_response" | grep -q "healthy"; then
    print_success "API is responding correctly"
else
    print_warning "API health check returned unexpected response"
    echo "  Response: $api_response"
fi

# Test frontend
print_info "Testing frontend..."
frontend_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 || echo "failed")
if [ "$frontend_response" = "200" ] || [ "$frontend_response" = "304" ]; then
    print_success "Frontend is responding correctly"
else
    print_warning "Frontend returned status code: $frontend_response"
fi

# Final Summary
print_header "Deployment Complete!"
echo "EchoGraph is now running!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Access URLs:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Frontend:    http://$SERVER_IP:3000"
echo "  API Docs:    http://$SERVER_IP:8000/docs"
echo "  API Health:  http://$SERVER_IP:8000/health"
echo "  n8n:         http://$SERVER_IP:5678"
echo "  MinIO:       http://$SERVER_IP:9001"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Service Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$COMPOSE_CMD ps
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Credentials Location:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  File: $(pwd)/.env"
echo ""
print_warning "IMPORTANT Security Notes:"
echo "  1. Change default passwords in .env file for production"
echo "  2. Set up firewall in Contabo Control Panel"
echo "  3. Ports 3000, 8000, 5678, 9000, 9001 must be open"
echo "  4. See: docs/TROUBLESHOOTING_CONNECTION.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Useful Commands:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  View logs:       ${COMPOSE_CMD} logs -f [service]"
echo "  Stop services:   ${COMPOSE_CMD} down"
echo "  Start services:  ${COMPOSE_CMD} up -d"
echo "  Restart service: ${COMPOSE_CMD} restart [service]"
echo "  Service status:  ${COMPOSE_CMD} ps"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Test upload: Visit http://$SERVER_IP:3000/dashboard"
echo "  2. Review API:  Visit http://$SERVER_IP:8000/docs"
echo "  3. Set up Nginx reverse proxy (see docs/deployment-contabo.md)"
echo "  4. Install SSL certificate with Let's Encrypt"
echo "  5. Configure backups"
echo ""
if [ "$COMPOSE_CMD" = "sudo docker-compose" ]; then
    print_warning "Note: Log out and back in to use Docker without sudo"
    echo "Or run: newgrp docker"
    echo ""
fi
print_success "Setup complete! Visit http://$SERVER_IP:3000 to get started."
echo ""
