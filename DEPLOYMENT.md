# EchoGraph Deployment Guide

This guide explains how to deploy EchoGraph on a new VM with automatic IP detection and configuration.

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/MarcusGraetsch/EchoGraph2.git
cd EchoGraph2
```

### 2. Generate Environment Configuration

The setup script will automatically detect your VM's IP address and configure all services accordingly:

```bash
./scripts/setup-env.sh
```

**What this does:**
- Auto-detects your VM's public IP address
- Generates `.env` file from `.env.example`
- Replaces `{{PUBLIC_IP}}` placeholders with your actual IP
- Configures all services (Frontend, API, Keycloak, n8n, MinIO)

**Manual IP Override:**
If you want to specify a custom IP address instead of auto-detection:

```bash
./scripts/setup-env.sh 192.168.1.100
```

### 3. Start Services

```bash
docker-compose up -d
```

Wait for all services to start (this may take 1-2 minutes). You can monitor the progress:

```bash
docker-compose logs -f
```

Press `Ctrl+C` to stop following logs.

### 4. Initialize Keycloak

After services are running, initialize Keycloak with the realm configuration:

```bash
./keycloak/init-keycloak.sh
```

This will:
- Wait for Keycloak to be ready
- Import the EchoGraph realm configuration
- Create the default admin user
- Configure OAuth2 clients

### 5. Access the Application

Once deployment is complete, you can access:

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **Frontend** | `http://YOUR_IP:3000` | Use Keycloak login |
| **API** | `http://YOUR_IP:8000` | N/A (uses Keycloak tokens) |
| **Keycloak** | `http://YOUR_IP:8080` | admin / admin_changeme |
| **n8n** | `http://YOUR_IP:5678` | admin / changeme |
| **MinIO Console** | `http://YOUR_IP:9001` | minioadmin / minioadmin |

Replace `YOUR_IP` with your VM's actual IP address.

## Advanced Configuration

### Environment Variables

The `.env` file is generated from `.env.example` with the following replacements:

| Placeholder | Description | Example |
|------------|-------------|---------|
| `{{PUBLIC_IP}}` | Your VM's public IP address | `178.18.254.21` |

### IP Detection Methods

The `detect-ip.sh` script tries multiple methods to find your IP (in order of preference):

1. **Public IP via external service** (ifconfig.me, icanhazip.com, api.ipify.org)
   - Best for servers accessible from the internet
   - Most reliable for public-facing deployments

2. **Primary network interface IP** (via `hostname -I`)
   - Good for private networks
   - May be a private IP (192.168.x.x, 10.x.x.x)

3. **Default route interface IP** (via `ip` command)
   - Fallback method
   - Uses IP of the interface with the default route

### Customizing Configuration

After generating `.env`, you can manually edit it to customize:

```bash
nano .env
```

Common customizations:
- **Change default passwords** (highly recommended for production!)
- **Configure HTTPS/SSL** (for production deployments)
- **Add AI API keys** (OpenAI, Anthropic, Cohere)
- **Adjust resource limits** (upload size, chunk size, etc.)

Remember to restart services after editing `.env`:

```bash
docker-compose down
docker-compose up -d
```

### Regenerating Configuration

If you need to regenerate the `.env` file (e.g., after IP change or moving to a new VM):

```bash
# Backup existing config (if you made manual changes)
cp .env .env.backup

# Regenerate with new IP
./scripts/setup-env.sh

# Or specify IP manually
./scripts/setup-env.sh 192.168.1.200
```

## Troubleshooting

### IP Detection Fails

If the automatic IP detection fails:

1. **Check network connectivity:**
   ```bash
   ping -c 3 8.8.8.8
   ```

2. **Manually find your IP:**
   ```bash
   # Public IP
   curl ifconfig.me

   # Or local IP
   hostname -I
   ```

3. **Generate .env with manual IP:**
   ```bash
   ./scripts/setup-env.sh YOUR_IP_HERE
   ```

### "Page Not Found" on Keycloak Login

This usually means Keycloak's hostname configuration doesn't match your access URL.

**Fix:**

1. Ensure `.env` has the correct IP:
   ```bash
   grep KEYCLOAK_HOSTNAME_URL .env
   ```
   Should show: `KEYCLOAK_HOSTNAME_URL=http://YOUR_IP:8080`

2. Restart Keycloak:
   ```bash
   docker-compose restart keycloak
   ```

3. Re-run initialization:
   ```bash
   ./keycloak/init-keycloak.sh
   ```

### Services Not Starting

**Check service status:**
```bash
docker-compose ps
```

**Check logs for errors:**
```bash
# All services
docker-compose logs

# Specific service
docker-compose logs keycloak
docker-compose logs api
docker-compose logs frontend
```

**Common issues:**

1. **Port already in use:**
   ```bash
   # Check what's using port 3000, 8000, or 8080
   sudo lsof -i :3000
   sudo lsof -i :8000
   sudo lsof -i :8080
   ```

2. **Database connection issues:**
   ```bash
   # Restart database
   docker-compose restart postgres

   # Check database logs
   docker-compose logs postgres
   ```

3. **Permission issues:**
   ```bash
   # Fix permissions on data directories
   sudo chown -R $USER:$USER data/
   ```

### CORS Errors in Browser

If you see CORS errors in the browser console:

1. **Check ALLOWED_ORIGINS in .env:**
   ```bash
   grep ALLOWED_ORIGINS .env
   ```
   Should include: `http://YOUR_IP:3000,http://YOUR_IP:8000`

2. **Restart API service:**
   ```bash
   docker-compose restart api
   ```

### Frontend Can't Connect to API

1. **Verify frontend environment variables:**
   ```bash
   docker-compose exec frontend printenv | grep NEXT_PUBLIC
   ```

2. **Rebuild frontend if variables are wrong:**
   ```bash
   docker-compose down frontend
   docker-compose build --no-cache frontend
   docker-compose up -d frontend
   ```

## Updating the Deployment

### Updating Application Code

```bash
# Pull latest changes
git pull

# Rebuild and restart services
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Updating Keycloak Realm Configuration

If you modify `keycloak/echograph-realm.json`:

```bash
# Option 1: Delete Keycloak data (WARNING: loses users)
docker-compose down
docker volume rm echograph2_keycloak_data
docker-compose up -d
./keycloak/init-keycloak.sh

# Option 2: Update manually via Keycloak Admin Console
# Access http://YOUR_IP:8080/admin
# Login with admin credentials
# Make changes in the UI
```

## Production Deployment Checklist

Before deploying to production:

- [ ] Change ALL default passwords in `.env`
- [ ] Set strong `API_SECRET_KEY` (random 64+ character string)
- [ ] Set strong `KEYCLOAK_CLIENT_SECRET`
- [ ] Configure HTTPS/SSL certificates
- [ ] Update Keycloak realm: set `sslRequired: "all"`
- [ ] Configure proper CORS origins (remove wildcards)
- [ ] Set up firewall rules (allow only 80/443, block direct access to 8080, 5432, etc.)
- [ ] Enable Keycloak email verification
- [ ] Configure backup for PostgreSQL databases
- [ ] Set up monitoring and alerting
- [ ] Review and update security settings in `SECURITY.md`
- [ ] Configure domain names instead of IP addresses
- [ ] Set up reverse proxy (nginx/Caddy) for SSL termination
- [ ] Enable Docker secrets for sensitive values
- [ ] Set up log aggregation

## Multi-VM Deployment

To deploy on multiple VMs:

1. **Clone repository on each VM:**
   ```bash
   git clone https://github.com/MarcusGraetsch/EchoGraph2.git
   cd EchoGraph2
   ```

2. **Run setup on each VM:**
   ```bash
   ./scripts/setup-env.sh
   ```
   Each VM will automatically detect its own IP and configure accordingly.

3. **Customize per environment:**
   - Development: Use auto-detected private IPs
   - Staging: Use public IPs or domain names
   - Production: Use domain names with HTTPS

4. **Deploy:**
   ```bash
   docker-compose up -d
   ./keycloak/init-keycloak.sh
   ```

## Network Configuration

### Firewall Rules

For production, configure firewall to allow only necessary ports:

```bash
# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow SSH (change 22 to your SSH port)
sudo ufw allow 22/tcp

# Block direct access to internal services
sudo ufw deny 5432/tcp  # PostgreSQL
sudo ufw deny 6379/tcp  # Redis
sudo ufw deny 6333/tcp  # Qdrant

# Enable firewall
sudo ufw enable
```

### Reverse Proxy (Production)

For production, use a reverse proxy like nginx or Caddy:

**Example nginx configuration:**
```nginx
server {
    listen 80;
    server_name yourdomain.com;

    # Frontend
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # API
    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Keycloak
    location /auth {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Support

For issues or questions:
- Check the [Troubleshooting](#troubleshooting) section above
- Review logs: `docker-compose logs`
- Open an issue on GitHub
- See `SECURITY.md` for security-related configuration

## Additional Resources

- **Keycloak Documentation:** https://www.keycloak.org/documentation
- **Docker Compose Reference:** https://docs.docker.com/compose/
- **Next.js Documentation:** https://nextjs.org/docs
- **FastAPI Documentation:** https://fastapi.tiangolo.com/
