#!/bin/bash

# EchoGraph Deployment Script for Contabo/Ubuntu VMs
# This script automates the deployment process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    echo "Credentials saved to .env file:"
    echo "  - PostgreSQL Password: $POSTGRES_PASSWORD"
    echo "  - MinIO Secret Key: $MINIO_SECRET"
    echo "  - n8n Password: $N8N_PASSWORD"
    echo "  - API Secret Key: $API_SECRET"
    echo "  - Server IP: $SERVER_IP"
    echo ""
    print_warning "Save these credentials securely!"
    echo ""
else
    print_warning ".env file already exists, skipping"
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

# Try to start services
if $COMPOSE_CMD up -d 2>&1 | grep -v "attribute.*version.*obsolete"; then
    print_success "Services started successfully"
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

# Step 9: Wait for Services
print_header "Step 9: Waiting for Services to Start"
echo "Waiting 30 seconds for services to initialize..."
sleep 30

# Check service status
$COMPOSE_CMD ps

# Step 10: Initialize Database
print_header "Step 10: Initializing Database"
if $COMPOSE_CMD exec -T api python -c "from database import init_db; init_db()" 2>/dev/null; then
    print_success "Database initialized"
else
    print_warning "Database initialization may have failed. Check logs with: ${COMPOSE_CMD} logs api"
fi

# Final Summary
print_header "Deployment Complete!"
SERVER_IP=$(curl -s ifconfig.me)
echo "EchoGraph is now running!"
echo ""
echo "Access your application:"
echo "  • Frontend:    http://$SERVER_IP:3000"
echo "  • API Docs:    http://$SERVER_IP:8000/docs"
echo "  • n8n:         http://$SERVER_IP:5678"
echo "  • MinIO:       http://$SERVER_IP:9001"
echo ""
print_warning "IMPORTANT: Can't access the application?"
echo "1. Check Contabo Control Panel firewall settings"
echo "2. Ensure ports 3000, 8000, 5678, 9000, 9001 are open"
echo "3. See: docs/TROUBLESHOOTING_CONNECTION.md"
echo ""
echo "Credentials are saved in: $(pwd)/.env"
echo ""
echo "Useful commands:"
echo "  • View logs:       ${COMPOSE_CMD} logs -f"
echo "  • Stop services:   ${COMPOSE_CMD} down"
echo "  • Start services:  ${COMPOSE_CMD} up -d"
echo "  • Restart:         ${COMPOSE_CMD} restart"
echo ""
echo "Next steps:"
echo "  1. Review and update .env file if needed"
echo "  2. Set up Nginx reverse proxy (see docs/deployment-contabo.md)"
echo "  3. Install SSL certificate with Let's Encrypt"
echo "  4. Configure backups"
echo ""
if [ "$COMPOSE_CMD" = "sudo docker-compose" ]; then
    print_warning "Note: Log out and back in to use Docker without sudo"
    echo "Or run: newgrp docker"
    echo ""
fi
print_success "Setup complete! Visit http://$SERVER_IP:3000 to get started."
