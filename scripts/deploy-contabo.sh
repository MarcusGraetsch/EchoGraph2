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
sudo ufw --force enable
print_success "Firewall configured"

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
    cp .env.example .env

    # Generate random secrets
    API_SECRET=$(openssl rand -hex 32)
    POSTGRES_PASSWORD=$(openssl rand -base64 24)
    MINIO_SECRET=$(openssl rand -hex 32)
    N8N_PASSWORD=$(openssl rand -base64 16)

    # Update .env file
    sed -i "s|API_SECRET_KEY=.*|API_SECRET_KEY=$API_SECRET|g" .env
    sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|g" .env
    sed -i "s|MINIO_SECRET_KEY=.*|MINIO_SECRET_KEY=$MINIO_SECRET|g" .env
    sed -i "s|N8N_BASIC_AUTH_PASSWORD=.*|N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD|g" .env

    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me)
    sed -i "s|NEXT_PUBLIC_API_URL=.*|NEXT_PUBLIC_API_URL=http://$SERVER_IP:8000|g" .env
    sed -i "s|NEXT_PUBLIC_WS_URL=.*|NEXT_PUBLIC_WS_URL=ws://$SERVER_IP:8000|g" .env

    print_success "Environment configured with random secure passwords"
    echo ""
    echo "Credentials saved to .env file:"
    echo "  - PostgreSQL Password: $POSTGRES_PASSWORD"
    echo "  - n8n Password: $N8N_PASSWORD"
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
print_warning "Note: You may need to log out and back in for Docker group changes to take effect"
echo "If this fails with permission errors, run: newgrp docker"
echo ""

# Try to start services
if docker-compose up -d; then
    print_success "Services started successfully"
else
    print_error "Failed to start services. Try running: newgrp docker"
    print_error "Then run: cd ~/EchoGraph2 && docker-compose up -d"
    exit 1
fi

# Step 9: Wait for Services
print_header "Step 9: Waiting for Services to Start"
echo "Waiting 30 seconds for services to initialize..."
sleep 30

# Check service status
docker-compose ps

# Step 10: Initialize Database
print_header "Step 10: Initializing Database"
if docker-compose exec -T api python -c "from database import init_db; init_db()" 2>/dev/null; then
    print_success "Database initialized"
else
    print_warning "Database initialization may have failed. Check logs with: docker-compose logs api"
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
echo "Credentials are saved in: $(pwd)/.env"
echo ""
echo "Useful commands:"
echo "  • View logs:       docker-compose logs -f"
echo "  • Stop services:   docker-compose down"
echo "  • Start services:  docker-compose up -d"
echo "  • Restart:         docker-compose restart"
echo ""
echo "Next steps:"
echo "  1. Review and update .env file if needed"
echo "  2. Set up Nginx reverse proxy (see docs/deployment-contabo.md)"
echo "  3. Install SSL certificate with Let's Encrypt"
echo "  4. Configure backups"
echo ""
print_success "Setup complete! Visit http://$SERVER_IP:3000 to get started."
