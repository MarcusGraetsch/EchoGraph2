# Quick Start: Deploy EchoGraph on Your Contabo VM

## Important: User Setup First

**If you're logged in as root**, create a non-root user first:

```bash
# 1. Create a new user
adduser echograph

# 2. Add to sudo group
usermod -aG sudo echograph

# 3. Switch to the new user
su - echograph

# 4. Now you're ready to deploy!
```

## TL;DR - Fastest Method

SSH into your Contabo VM (as non-root user) and run:

```bash
# Clone repository
git clone https://github.com/MarcusGraetsch/EchoGraph2.git
cd EchoGraph2

# Run deployment script
./scripts/deploy-contabo.sh
```

**Note:** The script must be run as a regular user with sudo privileges, not as root.

That's it! 🎉 The script will:
- Update your system
- Install Docker & Docker Compose
- Clone EchoGraph
- Generate secure passwords
- Configure services
- Start everything

## Access Your Application

After deployment completes (5-10 minutes), access:

- **Frontend**: http://YOUR_SERVER_IP:3000
- **API**: http://YOUR_SERVER_IP:8000/docs
- **n8n**: http://YOUR_SERVER_IP:5678
- **MinIO**: http://YOUR_SERVER_IP:9001

## What the Script Does

1. ✅ Updates Ubuntu system packages
2. ✅ Configures firewall (UFW)
3. ✅ Installs Docker & Docker Compose
4. ✅ Clones EchoGraph repository
5. ✅ Generates secure random passwords
6. ✅ Creates .env configuration
7. ✅ Starts all 8 Docker services
8. ✅ Initializes PostgreSQL database

## Manual Step-by-Step (If Preferred)

If you prefer manual control, follow the comprehensive guide:

📖 **[Full Deployment Guide](deployment-contabo.md)**

## After Deployment

### View Running Services

```bash
cd ~/EchoGraph2
docker-compose ps
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
```

### Stop/Start Services

```bash
# Stop
docker-compose down

# Start
docker-compose up -d

# Restart
docker-compose restart
```

### Check Your Credentials

```bash
cd ~/EchoGraph2
cat .env | grep -E "(PASSWORD|SECRET_KEY)"
```

## Production Setup (Optional)

For production deployment with domain and SSL:

### 1. Point Your Domain

Add DNS A records:
- `your-domain.com` → Your server IP
- `api.your-domain.com` → Your server IP

### 2. Install Nginx & SSL

```bash
# Install Nginx
sudo apt install -y nginx certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com -d api.your-domain.com
```

### 3. Update Environment

```bash
cd ~/EchoGraph2
nano .env

# Update these lines:
NEXT_PUBLIC_API_URL=https://api.your-domain.com
NEXT_PUBLIC_WS_URL=wss://api.your-domain.com

# Restart services
docker-compose down && docker-compose up -d
```

See [full production setup guide](deployment-contabo.md#part-5-production-setup-recommended) for Nginx configuration.

## Troubleshooting

### Services Won't Start

```bash
# Check Docker is running
sudo systemctl status docker

# Check logs
cd ~/EchoGraph2
docker-compose logs

# Restart services
docker-compose down
docker-compose up -d
```

### Permission Errors with Docker

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes
newgrp docker

# Try starting again
cd ~/EchoGraph2
docker-compose up -d
```

### Out of Memory

```bash
# Check memory
free -h

# Restart services to free memory
docker-compose restart

# Clean up Docker
docker system prune -a
```

### Can't Access Web Interface

```bash
# Check firewall
sudo ufw status

# Ensure ports are open
sudo ufw allow 3000/tcp
sudo ufw allow 8000/tcp

# Check services are running
docker-compose ps
```

## System Requirements

**Minimum:**
- 2 CPU cores
- 4 GB RAM
- 20 GB disk space
- Ubuntu 20.04 or 22.04 LTS

**Recommended:**
- 4 CPU cores
- 8 GB RAM
- 50 GB disk space

## Common Commands

```bash
# Navigate to project
cd ~/EchoGraph2

# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart services
docker-compose restart

# View logs
docker-compose logs -f

# Check service status
docker-compose ps

# Update application
git pull origin main
docker-compose down
docker-compose build
docker-compose up -d

# Backup database
docker-compose exec postgres pg_dump -U echograph echograph > backup.sql

# Clean Docker system
docker system prune -a
```

## Security Checklist

After deployment:

- [ ] Change default passwords in `.env`
- [ ] Configure firewall rules
- [ ] Set up SSL certificate
- [ ] Configure automatic backups
- [ ] Install fail2ban (brute force protection)
- [ ] Enable automatic security updates
- [ ] Set up monitoring

See [Security Guide](deployment-contabo.md#part-8-security-hardening) for details.

## Getting Help

- **Full Documentation**: [docs/deployment-contabo.md](deployment-contabo.md)
- **GitHub Issues**: https://github.com/MarcusGraetsch/EchoGraph2/issues
- **Logs**: `docker-compose logs -f`

## What's Next?

1. ✅ Access your application at http://YOUR_SERVER_IP:3000
2. 📝 Create your first admin user
3. 📄 Upload a document to test
4. 🔒 Set up SSL for production
5. 📊 Configure n8n workflows

---

**Need detailed instructions?** See the [full deployment guide](deployment-contabo.md).

**Deployed successfully?** Start using EchoGraph! 🚀
