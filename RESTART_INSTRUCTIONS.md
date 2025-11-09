# Quick Restart Guide - Keycloak Authentication Fix

## For Current Deployment (178.18.254.21)

If you're deploying on the existing VM at `178.18.254.21`, follow these steps:

### Step 1: Generate Environment Configuration

```bash
cd /path/to/EchoGraph2

# Auto-detect IP and generate .env file
./scripts/setup-env.sh
```

The script will:
- Detect your VM's IP address (178.18.254.21)
- Create `.env` file with correct configuration
- Configure Keycloak for public IP access

### Step 2: Restart Services

```bash
# Stop all services
docker-compose down

# Start services with new configuration
docker-compose up -d
```

### Step 3: Initialize Keycloak

```bash
# Wait for services to start (about 1-2 minutes)
docker-compose logs -f keycloak
# Press Ctrl+C when you see "Keycloak ... started"

# Initialize Keycloak with realm configuration
./keycloak/init-keycloak.sh
```

### Step 4: Test Authentication

1. Open browser to: `http://178.18.254.21:3000`
2. Click "Login" button
3. You should now see the **Keycloak login page** (not "Page not found")
4. Login with default credentials:
   - Username: `admin`
   - Password: `admin` (change on first login)

---

## What Was Fixed?

### The Problem
When clicking "Login" at `http://178.18.254.21:3000`, it redirected to Keycloak but showed "Page not found" because:
- Keycloak was configured for `localhost:8080` only
- Frontend redirect URIs didn't include the public IP
- Hostname validation rejected requests from 178.18.254.21

### The Solution
1. **Dynamic IP Configuration** - Created automated scripts that detect the VM's IP
2. **Updated Keycloak Realm** - Added redirect URIs for public IP access
3. **Environment Templates** - Modified `.env.example` to use `{{PUBLIC_IP}}` placeholders

---

## Alternative: Manual Configuration

If the automated script doesn't work, you can configure manually:

### Option 1: Generate with Custom IP

```bash
./scripts/setup-env.sh 178.18.254.21
```

### Option 2: Update Keycloak Admin Console

1. Access: `http://178.18.254.21:8080/admin`
2. Login with admin credentials
3. Select "echograph" realm
4. Go to "Clients" → "echograph-frontend"
5. Add to "Valid redirect URIs": `http://178.18.254.21:3000/*`
6. Add to "Web origins": `http://178.18.254.21:3000`
7. Click "Save"
8. Repeat for "echograph-api" with port 8000

Then restart:
```bash
docker-compose restart keycloak frontend api
```

---

## Troubleshooting

### Still Getting "Page not found"?

**Check Keycloak accessibility:**
```bash
curl -I http://178.18.254.21:8080
```
Should return HTTP 200 or 303, not 403.

**Check .env configuration:**
```bash
grep KEYCLOAK_HOSTNAME_URL .env
```
Should show: `KEYCLOAK_HOSTNAME_URL=http://178.18.254.21:8080`

**Restart Keycloak:**
```bash
docker-compose restart keycloak
./keycloak/init-keycloak.sh
```

### Getting CORS Errors?

**Check CORS configuration:**
```bash
grep ALLOWED_ORIGINS .env
```
Should include: `http://178.18.254.21:3000,http://178.18.254.21:8000`

**Restart API:**
```bash
docker-compose restart api
```

### Frontend Environment Variables Wrong?

**Check variables:**
```bash
docker-compose exec frontend printenv | grep NEXT_PUBLIC
```

**Rebuild if needed:**
```bash
docker-compose down frontend
docker-compose build --no-cache frontend
docker-compose up -d frontend
```

### Need to Start Fresh?

**Complete reset (WARNING: Deletes all data!):**
```bash
docker-compose down -v
./scripts/setup-env.sh
docker-compose up -d
./keycloak/init-keycloak.sh
```

---

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Keycloak Admin Console | admin | admin_changeme |
| EchoGraph Default User | admin | admin (temporary) |
| n8n | admin | changeme |
| MinIO | minioadmin | minioadmin |

**⚠️ IMPORTANT:** Change all default passwords for production!

---

## Service URLs

After successful deployment:

- **Frontend:** http://178.18.254.21:3000
- **API:** http://178.18.254.21:8000
- **API Docs:** http://178.18.254.21:8000/docs
- **Keycloak:** http://178.18.254.21:8080
- **Keycloak Admin:** http://178.18.254.21:8080/admin
- **n8n:** http://178.18.254.21:5678
- **MinIO Console:** http://178.18.254.21:9001

---

## For New Deployments on Different VMs

If you're deploying on a **different VM** (not 178.18.254.21), see the **[DEPLOYMENT.md](./DEPLOYMENT.md)** guide for comprehensive instructions.

The setup script will automatically detect the new VM's IP address and configure everything accordingly:

```bash
git clone https://github.com/MarcusGraetsch/EchoGraph2.git
cd EchoGraph2
./scripts/setup-env.sh
docker-compose up -d
./keycloak/init-keycloak.sh
```

No hardcoded IPs - works on any VM! 🚀
