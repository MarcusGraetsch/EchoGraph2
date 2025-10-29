# EchoGraph Deployment Guide for Contabo VM (Ubuntu)

## Prerequisites

- Contabo VM with Ubuntu 20.04 or 22.04 LTS
- SSH access to the server
- Root or sudo privileges
- Domain name (optional, but recommended for production)

## Part 1: Initial Server Setup

### 1.1 Connect to Your Server

```bash
ssh root@your-server-ip
# Or if using a non-root user:
ssh username@your-server-ip
```

### 1.2 Update System Packages

```bash
# Update package list
sudo apt update

# Upgrade installed packages
sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git vim ufw
```

### 1.3 Configure Firewall (UFW)

```bash
# Allow SSH (IMPORTANT: Do this first!)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow application ports (optional, for direct access)
sudo ufw allow 3000/tcp  # Frontend
sudo ufw allow 8000/tcp  # API

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### 1.4 Create Non-Root User (if not exists)

```bash
# Create user
sudo adduser echograph

# Add to sudo group
sudo usermod -aG sudo echograph

# Switch to new user
su - echograph
```

## Part 2: Install Docker and Docker Compose

### 2.1 Install Docker

```bash
# Install required packages
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list
sudo apt update

# Install Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Verify installation
sudo docker --version
```

### 2.2 Install Docker Compose

```bash
# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make executable
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

### 2.3 Configure Docker for Non-Root User

```bash
# Add current user to docker group
sudo usermod -aG docker $USER

# Apply group changes (logout and login, or use newgrp)
newgrp docker

# Test Docker without sudo
docker run hello-world
```

## Part 3: Clone and Configure EchoGraph

### 3.1 Clone Repository

```bash
# Navigate to home directory
cd ~

# Clone the repository
git clone https://github.com/MarcusGraetsch/EchoGraph2.git

# Enter directory
cd EchoGraph2
```

### 3.2 Configure Environment Variables

```bash
# Copy example environment file
cp .env.example .env

# Edit environment file
nano .env
```

**Update these critical settings:**

```bash
# Database - Use strong password
POSTGRES_USER=echograph
POSTGRES_PASSWORD=CHANGE_THIS_TO_STRONG_PASSWORD
POSTGRES_DB=echograph

# API Security - Generate random secret key
API_SECRET_KEY=GENERATE_RANDOM_SECRET_HERE
API_ACCESS_TOKEN_EXPIRE_MINUTES=30

# MinIO - Change credentials
MINIO_ACCESS_KEY=CHANGE_THIS
MINIO_SECRET_KEY=CHANGE_THIS_TO_STRONG_SECRET

# n8n - Change password
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=CHANGE_THIS_PASSWORD

# Application URLs (update with your domain or IP)
NEXT_PUBLIC_API_URL=http://your-server-ip:8000
NEXT_PUBLIC_WS_URL=ws://your-server-ip:8000

# Optional: AI API Keys
OPENAI_API_KEY=sk-your-key-here
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

**Generate secure secrets:**

```bash
# Generate random secret for API_SECRET_KEY
openssl rand -hex 32

# Generate random secret for MINIO_SECRET_KEY
openssl rand -hex 32
```

### 3.3 Create Data Directories

```bash
# Ensure data directories exist with correct permissions
mkdir -p data/raw data/processed
chmod 755 data/raw data/processed
```

## Part 4: Start EchoGraph Services

### 4.1 Pull Docker Images (Optional, to verify connectivity)

```bash
# Pull images first (optional, docker-compose will do this)
docker-compose pull
```

### 4.2 Start All Services

```bash
# Start services in detached mode
docker-compose up -d

# View logs
docker-compose logs -f

# Press Ctrl+C to stop following logs
```

### 4.3 Verify Services are Running

```bash
# Check running containers
docker-compose ps

# All services should show "Up" status
```

Expected output:
```
NAME                    STATUS              PORTS
echograph-api           Up (healthy)        0.0.0.0:8000->8000/tcp
echograph-frontend      Up                  0.0.0.0:3000->3000/tcp
echograph-postgres      Up (healthy)        0.0.0.0:5432->5432/tcp
echograph-redis         Up (healthy)        0.0.0.0:6379->6379/tcp
echograph-minio         Up (healthy)        0.0.0.0:9000-9001->9000-9001/tcp
echograph-qdrant        Up (healthy)        0.0.0.0:6333-6334->6333-6334/tcp
echograph-n8n           Up                  0.0.0.0:5678->5678/tcp
echograph-celery-worker Up                  N/A
```

### 4.4 Initialize Database

```bash
# Wait for services to be healthy (about 30 seconds)
sleep 30

# Initialize database tables
docker-compose exec api python -c "from database import init_db; init_db()"
```

### 4.5 Access Your Application

Open in your browser:

- **Frontend**: http://your-server-ip:3000
- **API Docs**: http://your-server-ip:8000/docs
- **n8n**: http://your-server-ip:5678
- **MinIO Console**: http://your-server-ip:9001

## Part 5: Production Setup (Recommended)

### 5.1 Set Up Nginx Reverse Proxy

```bash
# Install Nginx
sudo apt install -y nginx

# Create configuration file
sudo nano /etc/nginx/sites-available/echograph
```

**Add this configuration:**

```nginx
# Frontend
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# API
server {
    listen 80;
    server_name api.your-domain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket support
    location /api/ws/ {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }
}
```

**Enable site:**

```bash
# Create symbolic link
sudo ln -s /etc/nginx/sites-available/echograph /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### 5.2 Install SSL Certificate with Let's Encrypt

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com -d api.your-domain.com

# Follow prompts to complete setup

# Test auto-renewal
sudo certbot renew --dry-run
```

### 5.3 Update Environment Variables for HTTPS

```bash
# Edit .env file
nano .env

# Update URLs to use HTTPS
NEXT_PUBLIC_API_URL=https://api.your-domain.com
NEXT_PUBLIC_WS_URL=wss://api.your-domain.com
```

**Restart services:**

```bash
docker-compose down
docker-compose up -d
```

### 5.4 Configure Automatic Backups

```bash
# Create backup script
sudo nano /usr/local/bin/backup-echograph.sh
```

**Add this script:**

```bash
#!/bin/bash

# Configuration
BACKUP_DIR="/home/echograph/backups"
DATE=$(date +%Y%m%d_%H%M%S)
COMPOSE_DIR="/home/echograph/EchoGraph2"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup PostgreSQL database
docker-compose -f $COMPOSE_DIR/docker-compose.yml exec -T postgres \
  pg_dump -U echograph echograph | gzip > $BACKUP_DIR/postgres_$DATE.sql.gz

# Backup MinIO data
docker-compose -f $COMPOSE_DIR/docker-compose.yml exec -T minio \
  mc mirror /data $BACKUP_DIR/minio_$DATE/

# Keep only last 7 days of backups
find $BACKUP_DIR -name "postgres_*.sql.gz" -mtime +7 -delete
find $BACKUP_DIR -name "minio_*" -type d -mtime +7 -exec rm -rf {} +

echo "Backup completed: $DATE"
```

**Make executable and schedule:**

```bash
# Make script executable
sudo chmod +x /usr/local/bin/backup-echograph.sh

# Add to crontab (run daily at 2 AM)
crontab -e

# Add this line:
0 2 * * * /usr/local/bin/backup-echograph.sh >> /var/log/echograph-backup.log 2>&1
```

## Part 6: Monitoring and Maintenance

### 6.1 View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api

# Last 100 lines
docker-compose logs --tail=100 api
```

### 6.2 Restart Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart api

# Stop all services
docker-compose down

# Start all services
docker-compose up -d
```

### 6.3 Update Application

```bash
# Navigate to project directory
cd ~/EchoGraph2

# Pull latest changes
git pull origin main

# Rebuild and restart services
docker-compose down
docker-compose build
docker-compose up -d
```

### 6.4 Monitor Resource Usage

```bash
# Check Docker container stats
docker stats

# Check disk usage
df -h

# Check memory usage
free -h

# Check running processes
htop
```

## Part 7: Troubleshooting

### 7.1 Services Won't Start

```bash
# Check Docker service
sudo systemctl status docker

# Check logs for errors
docker-compose logs

# Check if ports are already in use
sudo netstat -tlnp | grep -E '(3000|8000|5432|6379|9000)'

# Remove and recreate containers
docker-compose down -v
docker-compose up -d
```

### 7.2 Database Connection Issues

```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Connect to database manually
docker-compose exec postgres psql -U echograph -d echograph

# Check database tables
\dt

# Exit
\q
```

### 7.3 Out of Disk Space

```bash
# Check disk usage
df -h

# Clean Docker system
docker system prune -a --volumes

# Remove old images
docker image prune -a
```

### 7.4 Memory Issues

```bash
# Check memory usage
free -h

# Restart services to free memory
docker-compose restart

# Limit container memory in docker-compose.yml
# Add under each service:
#   mem_limit: 512m
```

## Part 8: Security Hardening

### 8.1 Configure Fail2Ban (Prevent Brute Force)

```bash
# Install Fail2Ban
sudo apt install -y fail2ban

# Copy default config
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit configuration
sudo nano /etc/fail2ban/jail.local

# Enable SSH protection (ensure this is set):
[sshd]
enabled = true
port = 22
maxretry = 3
bantime = 3600

# Restart Fail2Ban
sudo systemctl restart fail2ban

# Check status
sudo fail2ban-client status
```

### 8.2 Regular Security Updates

```bash
# Enable automatic security updates
sudo apt install -y unattended-upgrades

# Configure automatic updates
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### 8.3 Change Default SSH Port (Optional)

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Change port (uncomment and modify)
Port 2222

# Restart SSH
sudo systemctl restart sshd

# Update firewall
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp
```

## Part 9: Quick Reference

### Start/Stop Commands

```bash
# Start all services
cd ~/EchoGraph2 && docker-compose up -d

# Stop all services
cd ~/EchoGraph2 && docker-compose down

# Restart all services
cd ~/EchoGraph2 && docker-compose restart

# View logs
cd ~/EchoGraph2 && docker-compose logs -f
```

### Access URLs

- Frontend: http://your-server-ip:3000 or https://your-domain.com
- API: http://your-server-ip:8000/docs or https://api.your-domain.com/docs
- n8n: http://your-server-ip:5678
- MinIO: http://your-server-ip:9001

### Important Files

- Configuration: `~/EchoGraph2/.env`
- Docker Compose: `~/EchoGraph2/docker-compose.yml`
- Nginx Config: `/etc/nginx/sites-available/echograph`
- Logs: `docker-compose logs -f`

## Part 10: Next Steps

1. **Create Admin User**: Once running, create an admin account through the API
2. **Configure n8n Workflows**: Set up automated workflows for document processing
3. **Test Document Upload**: Upload a sample PDF/DOCX to test the system
4. **Set Up Monitoring**: Install Prometheus/Grafana for advanced monitoring
5. **Configure Backups**: Ensure automatic backups are working
6. **Domain Setup**: Point your domain to the server IP
7. **SSL Certificate**: Install Let's Encrypt certificate for HTTPS

## Support

If you encounter issues:

1. Check logs: `docker-compose logs -f`
2. Verify services: `docker-compose ps`
3. Review documentation: `~/EchoGraph2/docs/`
4. GitHub Issues: https://github.com/MarcusGraetsch/EchoGraph2/issues

## Summary Checklist

- [ ] Server updated and firewall configured
- [ ] Docker and Docker Compose installed
- [ ] Repository cloned
- [ ] Environment variables configured with secure passwords
- [ ] Services started successfully
- [ ] Database initialized
- [ ] Application accessible via browser
- [ ] Nginx reverse proxy configured (optional)
- [ ] SSL certificate installed (optional)
- [ ] Backups configured
- [ ] Monitoring set up

---

**Your EchoGraph instance should now be running on your Contabo VM!** 🚀

Access it at: http://your-server-ip:3000
