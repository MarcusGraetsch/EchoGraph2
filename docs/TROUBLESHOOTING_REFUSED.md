# Connection Refused Error (ERR_CONNECTION_REFUSED)

## What This Error Means

`ERR_CONNECTION_REFUSED` is **different** from `ERR_CONNECTION_TIMED_OUT`:

- ✅ **Firewall is open** (good progress!)
- ❌ **Services aren't running** or aren't accessible

This usually means:
1. Docker containers aren't running
2. Containers crashed or failed to start
3. Containers are binding to wrong network interface (127.0.0.1 instead of 0.0.0.0)

## Quick Diagnosis

Run this diagnostic script on your VM:

```bash
cd ~/EchoGraph2
./scripts/diagnose.sh
```

This will check:
- Docker service status
- Which containers are running
- What's listening on ports
- Service logs

## Most Likely Issue: Services Not Running

### Check Docker Status

```bash
cd ~/EchoGraph2
sudo docker-compose ps
```

**Expected output:** All services showing "Up"

**If services show "Exit" or aren't listed:**

```bash
# View logs to see what went wrong
sudo docker-compose logs

# Restart all services
sudo docker-compose down
sudo docker-compose up -d

# Watch logs for errors
sudo docker-compose logs -f
```

## Common Causes & Fixes

### 1. Services Failed to Start

**Check logs:**
```bash
cd ~/EchoGraph2

# Check all logs
sudo docker-compose logs

# Check specific service
sudo docker-compose logs frontend
sudo docker-compose logs api
```

**Common errors:**
- **Port already in use**: Another service using the port
- **Image pull failed**: Network issue downloading images
- **Configuration error**: Issue in docker-compose.yml or .env

**Fix:**
```bash
# Stop everything
sudo docker-compose down

# Remove old containers
sudo docker-compose rm -f

# Start fresh
sudo docker-compose up -d
```

### 2. Docker Not Running

```bash
# Check Docker status
sudo systemctl status docker

# If not running, start it
sudo systemctl start docker

# Enable auto-start on boot
sudo systemctl enable docker

# Then restart services
cd ~/EchoGraph2
sudo docker-compose up -d
```

### 3. Wrong Network Binding

Check if services are listening on all interfaces (0.0.0.0) or just localhost (127.0.0.1):

```bash
sudo netstat -tlnp | grep -E '(3000|8000)'
```

**Good output (accessible externally):**
```
tcp6  0  0  :::3000  :::*  LISTEN  1234/docker-proxy
tcp6  0  0  :::8000  :::*  LISTEN  5678/docker-proxy
```

**Bad output (only accessible locally):**
```
tcp  0  0  127.0.0.1:3000  0.0.0.0:*  LISTEN
tcp  0  0  127.0.0.1:8000  0.0.0.0:*  LISTEN
```

If showing 127.0.0.1, the docker-compose.yml has wrong port configuration.

### 4. Check If Services Work Locally

Test from the VM itself:

```bash
# Test frontend
curl http://localhost:3000

# Test API
curl http://localhost:8000/health
curl http://localhost:8000/docs

# Test if accessible on all interfaces
curl http://0.0.0.0:3000
```

If localhost works but external access doesn't:
- Check `docker-compose.yml` port bindings
- Ensure ports are `"3000:3000"` not `"127.0.0.1:3000:3000"`

## Step-by-Step Fix

### Step 1: Stop Everything

```bash
cd ~/EchoGraph2
sudo docker-compose down
```

### Step 2: Check Docker Compose File

```bash
cd ~/EchoGraph2
cat docker-compose.yml | grep -A 2 "ports:"
```

Should show:
```yaml
ports:
  - "3000:3000"   # Good
  - "8000:8000"   # Good
```

NOT:
```yaml
ports:
  - "127.0.0.1:3000:3000"   # Bad - only localhost
```

### Step 3: Pull Images

```bash
cd ~/EchoGraph2
sudo docker-compose pull
```

### Step 4: Start Services

```bash
cd ~/EchoGraph2
sudo docker-compose up -d
```

### Step 5: Wait and Check

```bash
# Wait 30 seconds for services to start
sleep 30

# Check status
sudo docker-compose ps

# Check logs
sudo docker-compose logs --tail=50
```

### Step 6: Test Connectivity

```bash
# From the VM
curl http://localhost:3000

# Check what's listening
sudo netstat -tlnp | grep -E '(3000|8000)'
```

## Advanced Debugging

### Check Docker Network

```bash
# List networks
docker network ls

# Inspect the network
docker network inspect echograph2_echograph-network

# Check if containers are connected
docker network inspect echograph2_echograph-network | grep -A 5 "Containers"
```

### Rebuild Containers

If nothing else works, rebuild from scratch:

```bash
cd ~/EchoGraph2

# Stop and remove everything
sudo docker-compose down -v

# Remove images
sudo docker-compose rm -f

# Rebuild
sudo docker-compose build --no-cache

# Start
sudo docker-compose up -d

# Watch logs
sudo docker-compose logs -f
```

### Check System Resources

Services might fail if system is out of resources:

```bash
# Check memory
free -h

# Check disk space
df -h

# Check CPU
top
```

If low on memory:
```bash
# Restart services with limits
sudo docker-compose down
sudo docker system prune -a
sudo docker-compose up -d
```

## Verify Port Bindings in docker-compose.yml

The docker-compose.yml should have:

```yaml
frontend:
  ports:
    - "3000:3000"  # Accessible from outside

api:
  ports:
    - "8000:8000"  # Accessible from outside
```

If you see `127.0.0.1:3000:3000`, change it to just `3000:3000`.

## Still Not Working?

### Collect Information

Run these and share the output:

```bash
cd ~/EchoGraph2

# 1. Service status
sudo docker-compose ps

# 2. Logs
sudo docker-compose logs --tail=100

# 3. What's listening
sudo netstat -tlnp | grep -E '(3000|8000)'

# 4. Docker info
docker info

# 5. Test local connectivity
curl -v http://localhost:3000
curl -v http://localhost:8000/health
```

### Common Working Solution

Most of the time, this fixes it:

```bash
cd ~/EchoGraph2
sudo docker-compose down
sudo docker system prune -f
sudo docker-compose pull
sudo docker-compose up -d
sleep 30
sudo docker-compose ps
```

## After Services Are Running

Once `sudo docker-compose ps` shows all services "Up":

1. Test locally: `curl http://localhost:3000`
2. Check ports: `sudo netstat -tlnp | grep 3000`
3. Try external access: http://YOUR_IP:3000

If local access works but external doesn't:
- **Contabo Control Panel firewall** likely still blocking
- Check Contabo panel settings

---

**Back to:** [Connection Troubleshooting](TROUBLESHOOTING_CONNECTION.md) | [Quick Start](QUICK_START_VM.md)
