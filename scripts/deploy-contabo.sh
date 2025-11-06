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

# Self-update mechanism: Pull latest version of this script
# Skip if --no-update flag is passed (prevents infinite loop)
if [[ "$1" != "--no-update" ]] && [ -d ".git" ]; then
    echo "Checking for script updates..."
    git fetch origin >/dev/null 2>&1 || true

    LOCAL=$(git rev-parse @ 2>/dev/null || echo "")
    REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")

    if [ -n "$LOCAL" ] && [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
        print_warning "Updates available! Pulling latest changes..."
        git pull origin $(git branch --show-current)
        print_success "Script updated! Restarting with new version..."
        echo ""
        exec "$0" --no-update
    else
        print_success "Script is up to date"
    fi
    echo ""
fi

# Setup deployment logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOGFILE="${REPO_DIR}/deployment_$(date +%Y%m%d_%H%M%S).log"
LOGFILE_NAME="$(basename "${LOGFILE}")"

echo "Starting deployment at $(date)" > "${LOGFILE}"
echo "Log file: ${LOGFILE}"
echo ""

# Redirect all output to both console and log file
exec > >(tee -a "${LOGFILE}") 2>&1

print_info "Deployment logging to: ${LOGFILE_NAME}"
echo ""

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

# Step 5: Clone Repository (or detect existing)
print_header "Step 5: Locating EchoGraph Repository"

# Check if we're already inside the EchoGraph2 repository
if [ -f "docker-compose.yml" ] && [ -d ".git" ] && grep -q "echograph" docker-compose.yml 2>/dev/null; then
    print_success "Already in EchoGraph2 repository"
    REPO_DIR=$(pwd)

    # Pull latest changes
    print_info "Pulling latest changes from repository..."
    if git pull origin $(git branch --show-current) 2>&1 | grep -v "Already up to date"; then
        print_success "Repository updated to latest version"
    else
        print_success "Repository already up to date"
    fi

    # Check if there's a nested clone and warn about it
    if [ -d "EchoGraph2" ]; then
        print_warning "Found nested EchoGraph2 directory (from previous run)"
        echo "  This can be safely deleted: rm -rf EchoGraph2"
        echo ""
    fi

# Check if EchoGraph2 exists as subdirectory
elif [ -d "EchoGraph2" ]; then
    print_warning "EchoGraph2 directory already exists"
    read -p "Use existing directory? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd EchoGraph2
        REPO_DIR=$(pwd)

        # Pull latest changes
        print_info "Pulling latest changes from repository..."
        if git pull origin $(git branch --show-current) 2>&1 | grep -v "Already up to date"; then
            print_success "Repository updated to latest version"
        else
            print_success "Repository already up to date"
        fi

        print_success "Using existing repository"
    else
        rm -rf EchoGraph2
        git clone https://github.com/MarcusGraetsch/EchoGraph2.git
        cd EchoGraph2
        REPO_DIR=$(pwd)
        print_success "Repository cloned"
    fi

# Need to clone
else
    git clone https://github.com/MarcusGraetsch/EchoGraph2.git
    cd EchoGraph2
    REPO_DIR=$(pwd)
    print_success "Repository cloned"
fi

echo "  Working directory: $REPO_DIR"
echo ""

# Step 6: Configure Environment
print_header "Step 6: Configuring Environment"
if [ ! -f ".env" ]; then
    # Generate random secrets
    # Note: Use -hex for passwords that go in URLs (no special chars like +, /, =)
    API_SECRET=$(openssl rand -hex 32)
    POSTGRES_PASSWORD=$(openssl rand -hex 16)  # 32 chars, URL-safe (no +, /, =)
    MINIO_SECRET=$(openssl rand -hex 32)
    N8N_PASSWORD=$(openssl rand -base64 16)  # OK to use base64 (not in URL)
    KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -hex 16)  # Keycloak admin password
    KEYCLOAK_DB_PASSWORD=$(openssl rand -hex 16)  # Keycloak database password
    KEYCLOAK_CLIENT_SECRET=$(openssl rand -hex 32)  # API client secret

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

# Keycloak Configuration
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD
KEYCLOAK_DB=keycloak
KEYCLOAK_DB_USER=keycloak
KEYCLOAK_DB_PASSWORD=$KEYCLOAK_DB_PASSWORD
KEYCLOAK_REALM=echograph
KEYCLOAK_CLIENT_ID=echograph-api
KEYCLOAK_CLIENT_SECRET=$KEYCLOAK_CLIENT_SECRET
KEYCLOAK_FRONTEND_CLIENT_ID=echograph-frontend
KEYCLOAK_SERVER_URL=http://keycloak:8080
KEYCLOAK_PUBLIC_URL=http://$SERVER_IP:8080

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
    echo "  PostgreSQL Password:     $POSTGRES_PASSWORD"
    echo "  MinIO Secret Key:        $MINIO_SECRET"
    echo "  n8n Username:            admin"
    echo "  n8n Password:            $N8N_PASSWORD"
    echo "  Keycloak Admin Username: admin"
    echo "  Keycloak Admin Password: $KEYCLOAK_ADMIN_PASSWORD"
    echo "  Keycloak DB Password:    $KEYCLOAK_DB_PASSWORD"
    echo "  API Secret Key:          $API_SECRET"
    echo "  Server IP:               $SERVER_IP"
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

# Step 7.5: Check System Resources
print_header "Step 7.5: Checking System Resources"

# Function to check if port is available
check_port() {
    local port=$1
    local service=$2
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -ln 2>/dev/null | grep -q ":$port "; then
        print_error "Port $port ($service) is already in use"
        echo "  To see what's using it: sudo lsof -i :$port"
        echo "  To kill the process: sudo kill \$(sudo lsof -t -i:$port)"
        return 1
    else
        print_success "Port $port ($service) is available"
        return 0
    fi
}

# Function to convert memory values to MB
to_mb() {
    local value=$1
    local unit=$2
    case $unit in
        kB) echo $((value / 1024)) ;;
        MB) echo $value ;;
        GB) echo $((value * 1024)) ;;
        *) echo $value ;;
    esac
}

# Check all required ports
print_info "Checking port availability..."
ports_ok=true
check_port 3000 "Frontend" || ports_ok=false
check_port 8000 "API" || ports_ok=false
check_port 5432 "PostgreSQL" || ports_ok=false
check_port 6379 "Redis" || ports_ok=false
check_port 6333 "Qdrant" || ports_ok=false
check_port 6334 "Qdrant gRPC" || ports_ok=false
check_port 9000 "MinIO" || ports_ok=false
check_port 9001 "MinIO Console" || ports_ok=false
check_port 5678 "n8n" || ports_ok=false

if [ "$ports_ok" = false ]; then
    echo ""
    print_error "Some ports are already in use!"
    echo ""
    echo "You have two options:"
    echo "  1. Stop the services using these ports"
    echo "  2. Use different ports (requires editing docker-compose.yml)"
    echo ""
    read -p "Continue anyway? (NOT recommended) (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
print_info "Checking system resources..."

# Check RAM
total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_ram_mb=$(to_mb $total_ram kB)
available_ram=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
available_ram_mb=$(to_mb $available_ram kB)

echo "  Total RAM: ${total_ram_mb} MB"
echo "  Available RAM: ${available_ram_mb} MB"

if [ $total_ram_mb -lt 4096 ]; then
    print_error "WARNING: Less than 4GB RAM detected (${total_ram_mb} MB)"
    echo "  Recommended: At least 4GB RAM (8GB preferred)"
    echo "  EchoGraph may run slowly or crash with insufficient memory"
    echo ""
elif [ $total_ram_mb -lt 8192 ]; then
    print_warning "Only ${total_ram_mb} MB RAM detected"
    echo "  Recommended: 8GB RAM for optimal performance"
    echo "  Current RAM may be sufficient but performance could be limited"
    echo ""
else
    print_success "RAM: ${total_ram_mb} MB (sufficient)"
fi

if [ $available_ram_mb -lt 2048 ]; then
    print_error "WARNING: Less than 2GB available RAM (${available_ram_mb} MB)"
    echo "  Consider stopping other services or upgrading RAM"
    echo ""
fi

# Check CPU cores
cpu_cores=$(nproc)
echo "  CPU Cores: $cpu_cores"

if [ $cpu_cores -lt 2 ]; then
    print_error "WARNING: Less than 2 CPU cores detected ($cpu_cores)"
    echo "  Recommended: At least 2 CPU cores (4+ preferred)"
    echo "  EchoGraph may run very slowly with single core"
    echo ""
elif [ $cpu_cores -lt 4 ]; then
    print_warning "Only $cpu_cores CPU cores detected"
    echo "  Recommended: 4+ CPU cores for optimal performance"
    echo ""
else
    print_success "CPU Cores: $cpu_cores (sufficient)"
fi

# Check disk space
disk_space=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
echo "  Available Disk Space: ${disk_space} GB"

if [ $disk_space -lt 10 ]; then
    print_error "WARNING: Less than 10GB disk space available (${disk_space} GB)"
    echo "  Recommended: At least 20GB free space for documents and databases"
    echo "  Deployment may fail or system may crash"
    echo ""
    read -p "Continue anyway? (NOT recommended) (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
elif [ $disk_space -lt 20 ]; then
    print_warning "Only ${disk_space} GB disk space available"
    echo "  Recommended: At least 20GB free space"
    echo "  May run out of space with large document uploads"
    echo ""
else
    print_success "Disk Space: ${disk_space} GB (sufficient)"
fi

# Resource summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Resource Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RAM:        ${total_ram_mb} MB (${available_ram_mb} MB available)"
echo "  CPU:        ${cpu_cores} cores"
echo "  Disk:       ${disk_space} GB available"
echo "  Ports:      $([ "$ports_ok" = true ] && echo "All clear" || echo "Some in use")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Minimum requirements check
if [ $total_ram_mb -lt 3072 ] || [ $cpu_cores -lt 1 ] || [ $disk_space -lt 5 ]; then
    print_error "System does not meet minimum requirements!"
    echo ""
    echo "Minimum Requirements:"
    echo "  - RAM: 3GB (you have: ${total_ram_mb} MB)"
    echo "  - CPU: 1 core (you have: $cpu_cores)"
    echo "  - Disk: 5GB (you have: ${disk_space} GB)"
    echo ""
    read -p "Continue anyway? (May fail or crash) (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 8: Start Services
print_header "Step 8: Starting Docker Services"

# PRODUCTION MODE: Use docker-compose.prod.yml without code volume mounts
# This ensures containers use code from Docker images, not VM filesystem
# Development mode (docker-compose.yml) uses volume mounts for hot-reload
print_info "Using production configuration (docker-compose.prod.yml)"

# Check if we can run docker without sudo
if docker ps >/dev/null 2>&1; then
    print_success "Docker permissions OK"
    DOCKER_CMD="docker"
    COMPOSE_CMD="docker-compose -f docker-compose.prod.yml"
else
    print_warning "Docker group changes not yet active, using sudo for this session"
    DOCKER_CMD="sudo docker"
    COMPOSE_CMD="sudo docker-compose -f docker-compose.prod.yml"
fi

# Stop any existing services and clean volumes for fresh start
print_info "Ensuring clean environment..."

# Check if there are existing volumes
existing_volumes=$($DOCKER_CMD volume ls -q | grep -E "echograph|EchoGraph2" || true)

if [ -n "$existing_volumes" ]; then
    print_warning "Found existing Docker volumes from previous deployment"
    echo ""
    echo "  Volumes found:"
    echo "$existing_volumes" | sed 's/^/    - /'
    echo ""
    print_error "⚠ CRITICAL: Postgres volume must be removed to prevent password mismatches"
    echo ""
    echo "  Why? Postgres volumes contain encrypted passwords from previous deployments."
    echo "  If not removed, the API will fail with 'password authentication failed'."
    echo ""
    echo "Options:"
    echo "  1. Remove ALL volumes (recommended for fresh deployment)"
    echo "  2. Remove ONLY postgres volume (keeps uploaded files)"
    echo "  3. Keep volumes (NOT recommended - will likely fail)"
    echo ""
    read -p "Choose option (1/2/3): " -n 1 -r
    echo
    echo ""

    case $REPLY in
        1)
            print_info "Removing all volumes for complete fresh start..."
            $COMPOSE_CMD down -v 2>/dev/null || true
            print_success "All volumes removed"
            ;;
        2)
            print_info "Removing only postgres volume..."
            $COMPOSE_CMD down 2>/dev/null || true
            postgres_volume=$($DOCKER_CMD volume ls -q | grep -i postgres || true)
            if [ -n "$postgres_volume" ]; then
                $DOCKER_CMD volume rm $postgres_volume 2>/dev/null || true
                print_success "Postgres volume removed: $postgres_volume"
            fi
            ;;
        3)
            print_error "Keeping existing volumes - password mismatch likely to occur"
            echo ""
            echo "If deployment fails with 'password authentication failed', run:"
            echo "  sudo docker-compose down"
            echo "  sudo docker volume rm echograph2_postgres_data"
            echo "  sudo docker-compose up -d"
            echo ""
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            $COMPOSE_CMD down 2>/dev/null || true
            ;;
        *)
            print_error "Invalid option. Defaulting to option 1 (remove all volumes)"
            $COMPOSE_CMD down -v 2>/dev/null || true
            print_success "All volumes removed"
            ;;
    esac
else
    # No existing volumes, just stop any running containers
    $COMPOSE_CMD down 2>/dev/null || true
    print_success "Environment clean - no existing volumes"
fi

echo ""

# Build Docker images with latest code
print_info "Building Docker images with latest code..."
echo "  This ensures containers use code from git repo, not cached layers"
echo ""

if $COMPOSE_CMD build --no-cache api celery-worker frontend 2>&1 | grep -v "attribute.*version.*obsolete"; then
    print_success "Docker images built successfully"
else
    print_error "Failed to build Docker images"
    echo ""
    echo "This is critical - without fresh build, containers will use old code!"
    echo ""
    read -p "Continue anyway? (NOT recommended) (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

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

# Step 8.5: Setup Keycloak Database
print_header "Step 8.5: Setting up Keycloak Database"
print_info "Ensuring Keycloak database exists..."

if [ -f "$REPO_DIR/scripts/setup-keycloak-database.sh" ]; then
    if bash "$REPO_DIR/scripts/setup-keycloak-database.sh"; then
        print_success "Keycloak database setup completed"
    else
        print_warning "Keycloak database setup failed - Keycloak may not start properly"
        echo "  You can run it manually later with:"
        echo "  cd $REPO_DIR && ./scripts/setup-keycloak-database.sh"
    fi
else
    print_warning "Keycloak database setup script not found"
    echo "  Keycloak may fail to start if database doesn't exist"
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
check_service "keycloak" || services_ok=false

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
    api_logs=$($COMPOSE_CMD logs --tail=30 api 2>&1)

    if echo "$api_logs" | grep -q "ImportError\|ModuleNotFoundError\|NameError"; then
        if echo "$api_logs" | grep -q "NameError.*StorageClient"; then
            print_error "StorageClient NameError detected - OLD CODE in container!"
            echo "  Issue: Docker container built with old/cached code"
            echo "  Root cause: Container image not rebuilt after git pull"
            echo "  Fix: Rebuilding with --no-cache to force fresh code..."
        else
            print_error "Python import error detected"
            echo "  Issue: Missing Python dependencies or import path issues"
            echo "  Fix: Rebuilding API container with fresh dependencies..."
        fi
        $COMPOSE_CMD build --no-cache api
        $COMPOSE_CMD up -d api
        sleep 15

    elif echo "$api_logs" | grep -q "password authentication failed"; then
        print_error "Database authentication error detected"
        echo "  Issue: API cannot connect to PostgreSQL with current password"
        echo "  Checking .env file for password mismatch..."

        # Check if passwords match
        postgres_pass=$(grep "^POSTGRES_PASSWORD=" .env | cut -d'=' -f2)
        db_url_pass=$(grep "^DATABASE_URL=" .env | grep -oP 'echograph:\K[^@]+')

        if [ "$postgres_pass" != "$db_url_pass" ]; then
            print_error "Password mismatch detected in .env file!"
            echo "  POSTGRES_PASSWORD: $postgres_pass"
            echo "  DATABASE_URL password: $db_url_pass"
            echo "  Fix: Updating DATABASE_URL to match POSTGRES_PASSWORD..."
            sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://echograph:$postgres_pass@postgres:5432/echograph|g" .env
            print_success "DATABASE_URL updated"
        fi

        print_warning "Root cause: Postgres volume has old password from previous deployment"
        echo ""
        echo "  The postgres data volume was initialized with a different password."
        echo "  Postgres does not change passwords when restarted - volume must be removed."
        echo ""
        print_info "Fix: Removing postgres volume and reinitializing database..."
        echo ""

        # Stop all services
        print_info "Stopping all services..."
        $COMPOSE_CMD down

        # Remove postgres volume specifically
        postgres_volume=$($DOCKER_CMD volume ls -q | grep -i postgres || true)
        if [ -n "$postgres_volume" ]; then
            print_info "Removing postgres volume: $postgres_volume"
            $DOCKER_CMD volume rm $postgres_volume 2>/dev/null || true
            print_success "Postgres volume removed"
        else
            print_warning "No postgres volume found to remove"
        fi

        # Restart services (postgres will initialize fresh with correct password)
        print_info "Starting postgres first to initialize with correct password..."
        $COMPOSE_CMD up -d postgres
        sleep 10

        print_info "Starting remaining services..."
        $COMPOSE_CMD up -d
        sleep 15

        print_success "Services restarted with fresh postgres database"

    elif echo "$api_logs" | grep -q "Address already in use\|bind.*failed"; then
        print_error "Port conflict detected"
        echo "  Issue: API port 8000 is already in use"
        echo "  Check what's using the port: sudo lsof -i :8000"
        echo "  Kill the process: sudo kill \$(sudo lsof -t -i:8000)"
        echo ""
        read -p "Have you freed port 8000? Press Enter to retry..."
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

    elif echo "$api_logs" | grep -q "Out of memory\|MemoryError\|Cannot allocate memory"; then
        print_error "Out of memory error detected"
        echo "  Issue: Insufficient RAM to run all services"
        echo "  Current system memory:"
        free -h
        echo ""
        echo "  Solutions:"
        echo "    1. Stop other services to free memory"
        echo "    2. Upgrade server RAM (recommended: 8GB+)"
        echo "    3. Add swap space (temporary solution)"
        echo ""
        read -p "Press Enter to continue (services may continue to fail)..."

    else
        print_warning "Unable to identify specific error. Showing recent API logs:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        $COMPOSE_CMD logs --tail=15 api
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
        echo "  ${COMPOSE_CMD} logs celery-worker"
        echo ""
        echo "Common issues and solutions:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  1. Database password mismatch:"
        echo "     Check: grep PASSWORD .env"
        echo "     Fix: Ensure POSTGRES_PASSWORD matches password in DATABASE_URL"
        echo ""
        echo "  2. Port conflicts:"
        echo "     Check: sudo lsof -i :8000"
        echo "     Fix: sudo kill \$(sudo lsof -t -i:8000)"
        echo ""
        echo "  3. Import errors:"
        echo "     Fix: ${COMPOSE_CMD} build --no-cache api && ${COMPOSE_CMD} up -d api"
        echo ""
        echo "  4. Resource limits:"
        echo "     Check: free -h && df -h"
        echo "     Fix: Stop other services or upgrade server"
        echo ""
        echo "  5. Rebuild everything (last resort):"
        echo "     ${COMPOSE_CMD} down -v"
        echo "     ${COMPOSE_CMD} build --no-cache"
        echo "     ${COMPOSE_CMD} up -d"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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

# Step 10: Initialize Keycloak
print_header "Step 10: Initialize Keycloak Realm"
print_info "Configuring Keycloak with EchoGraph realm..."

if [ -f "$REPO_DIR/keycloak/init-keycloak.sh" ]; then
    export KEYCLOAK_SERVER_URL="http://localhost:8080"
    export KEYCLOAK_ADMIN
    export KEYCLOAK_ADMIN_PASSWORD
    export KEYCLOAK_REALM
    export KEYCLOAK_CLIENT_ID
    export KEYCLOAK_CLIENT_SECRET

    print_info "Running Keycloak initialization script (timeout: 5 minutes)..."

    # Run with timeout to prevent hanging indefinitely
    timeout 300 bash "$REPO_DIR/keycloak/init-keycloak.sh"
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        print_success "Keycloak realm configured successfully"
    elif [ $EXIT_CODE -eq 124 ]; then
        print_error "Keycloak initialization timed out after 5 minutes"
        echo "  This usually means Keycloak is taking too long to respond."
        echo "  You can run it manually later with:"
        echo "  cd $REPO_DIR && ./keycloak/init-keycloak.sh"
        echo "  Or check Keycloak logs: ${COMPOSE_CMD} logs keycloak"
    else
        print_warning "Keycloak initialization script failed (exit code: $EXIT_CODE)"
        echo "  You can run it manually later with:"
        echo "  cd $REPO_DIR && ./keycloak/init-keycloak.sh"
        echo "  Or check Keycloak logs: ${COMPOSE_CMD} logs keycloak"
    fi
else
    print_warning "Keycloak initialization script not found"
    echo "  Skipping automatic realm configuration"
    echo "  You'll need to configure Keycloak manually"
fi

# Step 11: Test API Endpoint
print_header "Step 11: Testing API Endpoints"
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
echo "🎉 EchoGraph is now running!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                    🌐 ALL SERVICE URLs                         "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📱 User Interfaces:"
echo "     Frontend (Main App):    http://$SERVER_IP:3000"
echo "     Keycloak (Auth):        http://$SERVER_IP:8080"
echo "     n8n (Workflows):        http://$SERVER_IP:5678"
echo "     MinIO Console (Files):  http://$SERVER_IP:9001"
echo ""
echo "  🔧 API & Services:"
echo "     API Documentation:      http://$SERVER_IP:8000/docs"
echo "     API Health Check:       http://$SERVER_IP:8000/health"
echo "     API Base URL:           http://$SERVER_IP:8000"
echo ""
echo "  💾 Database & Storage:"
echo "     PostgreSQL:             postgres:5432 (internal only)"
echo "     Redis:                  redis:6379 (internal only)"
echo "     Qdrant (Vectors):       localhost:6333 (internal only)"
echo "     MinIO S3 API:           http://$SERVER_IP:9000"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                    🔐 PASSWORD SECURITY ADVICE                 "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_warning "⚠️  IMPORTANT: Change your passwords IMMEDIATELY for production!"
echo ""
echo "  WHY? Your current passwords are:"
echo "    ✓ Auto-generated during deployment"
echo "    ✓ Stored in plain text in .env file"
echo "    ✓ Potentially visible in logs"
echo ""
echo "  📋 Current Credentials (from .env file):"
echo "  ─────────────────────────────────────────────────────────────"

# Read and display current passwords
if [ -f ".env" ]; then
    KEYCLOAK_ADMIN_USER=$(grep "^KEYCLOAK_ADMIN=" .env | cut -d'=' -f2)
    KEYCLOAK_ADMIN_PASS=$(grep "^KEYCLOAK_ADMIN_PASSWORD=" .env | cut -d'=' -f2)
    N8N_USER=$(grep "^N8N_BASIC_AUTH_USER=" .env | cut -d'=' -f2)
    N8N_PASS=$(grep "^N8N_BASIC_AUTH_PASSWORD=" .env | cut -d'=' -f2)
    MINIO_USER=$(grep "^MINIO_ACCESS_KEY=" .env | cut -d'=' -f2)
    MINIO_PASS=$(grep "^MINIO_SECRET_KEY=" .env | cut -d'=' -f2)

    echo "     Keycloak:  Username: ${KEYCLOAK_ADMIN_USER}  Password: ${KEYCLOAK_ADMIN_PASS}"
    echo "     n8n:       Username: ${N8N_USER}  Password: ${N8N_PASS}"
    echo "     MinIO:     Username: ${MINIO_USER}  Password: ${MINIO_PASS}"
fi
echo "  ─────────────────────────────────────────────────────────────"
echo ""
echo "  📝 HOW TO CHANGE PASSWORDS:"
echo ""
echo "  1️⃣  KEYCLOAK (Authentication System):"
echo "     • Login: http://$SERVER_IP:8080"
echo "     • Click 'Administration Console'"
echo "     • Login with admin credentials above"
echo "     • Click 'admin' (top right) → 'Manage account' → 'Password'"
echo "     • After changing, update .env:"
echo "       nano ~/EchoGraph2/.env"
echo "       Change: KEYCLOAK_ADMIN_PASSWORD=<new_password>"
echo ""
echo "  2️⃣  n8n (Workflow Automation):"
echo "     • Edit .env: nano ~/EchoGraph2/.env"
echo "     • Change: N8N_BASIC_AUTH_PASSWORD=<new_password>"
echo "     • Restart: cd ~/EchoGraph2 && ${COMPOSE_CMD} restart n8n"
echo ""
echo "  3️⃣  MinIO (File Storage):"
echo "     • Login: http://$SERVER_IP:9001"
echo "     • Go to 'Identity' → 'Users' → 'minioadmin'"
echo "     • Change password OR create new admin user"
echo "     • Update .env:"
echo "       nano ~/EchoGraph2/.env"
echo "       Change: MINIO_SECRET_KEY=<new_password>"
echo "     • Restart: cd ~/EchoGraph2 && ${COMPOSE_CMD} restart minio api"
echo ""
echo "  4️⃣  PostgreSQL Database:"
echo "     ⚠️  WARNING: Requires database volume rebuild!"
echo "     • Only change if absolutely necessary"
echo "     • Process:"
echo "       1. Backup data first!"
echo "       2. Edit .env: nano ~/EchoGraph2/.env"
echo "       3. Update POSTGRES_PASSWORD AND DATABASE_URL"
echo "       4. Remove volume: ${COMPOSE_CMD} down && sudo docker volume rm echograph2_postgres_data"
echo "       5. Restart: ${COMPOSE_CMD} up -d"
echo ""
echo "  🎯 RECOMMENDED ACTION:"
echo "     → Change Keycloak, n8n, and MinIO passwords NOW"
echo "     → Leave PostgreSQL password (only accessible internally)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                    📊 SERVICE STATUS                           "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$COMPOSE_CMD ps
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                    📁 CREDENTIALS FILE                         "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  All passwords stored in: $(pwd)/.env"
echo "  View file: cat .env"
echo "  Edit file: nano .env"
echo ""
print_warning "🔒 Security Notes:"
echo "  • .env file contains all secrets - keep it secure!"
echo "  • Never commit .env to git (already in .gitignore)"
echo "  • Backup .env file securely"
echo "  • Set up firewall in Contabo Control Panel"
echo "  • Required open ports: 22, 80, 443, 3000, 8000, 8080, 5678, 9000, 9001"
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
echo "  Note: Production mode uses docker-compose.prod.yml"
echo "        For development with hot-reload, use docker-compose.yml"
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
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Deployment Log File:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  File name: ${LOGFILE_NAME}"
echo "  Full path: ${LOGFILE}"
echo "  View log:  cat ${LOGFILE_NAME}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_success "Setup complete! Visit http://$SERVER_IP:3000 to get started."
echo ""
