# Troubleshooting: Can't Access Application (Connection Timeout)

## Problem

When accessing your application via `http://YOUR_IP:3000`, you get:
- `ERR_CONNECTION_TIMED_OUT`
- `This site can't be reached`
- `Connection refused`

## Quick Fix (Most Common)

This is usually a **firewall issue**. Run these commands on your VM:

```bash
# Check if UFW is blocking ports
sudo ufw status

# If UFW is active but ports aren't listed, add them:
sudo ufw allow 3000/tcp
sudo ufw allow 8000/tcp
sudo ufw allow 5678/tcp
sudo ufw allow 9000/tcp
sudo ufw allow 9001/tcp

# Reload firewall
sudo ufw reload

# Verify rules are added
sudo ufw status
```

You should see output like:
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
3000/tcp                   ALLOW       Anywhere
8000/tcp                   ALLOW       Anywhere
```

## Contabo Firewall (If Above Doesn't Work)

Contabo has **TWO firewalls**:
1. Server firewall (UFW) - configured above ✅
2. **Contabo Control Panel firewall** - you need to configure this too!

### Steps to Configure Contabo Firewall:

1. **Log into Contabo Customer Control Panel**
   - Go to: https://my.contabo.com/

2. **Navigate to your VPS**
   - Click on "Your Services"
   - Select your VPS

3. **Configure Firewall Rules**
   - Look for "Firewall" or "Security" settings
   - Add these rules:

   | Port | Protocol | Source | Description |
   |------|----------|--------|-------------|
   | 22   | TCP      | 0.0.0.0/0 | SSH |
   | 80   | TCP      | 0.0.0.0/0 | HTTP |
   | 443  | TCP      | 0.0.0.0/0 | HTTPS |
   | 3000 | TCP      | 0.0.0.0/0 | Frontend |
   | 8000 | TCP      | 0.0.0.0/0 | API |
   | 5678 | TCP      | 0.0.0.0/0 | n8n |
   | 9000 | TCP      | 0.0.0.0/0 | MinIO API |
   | 9001 | TCP      | 0.0.0.0/0 | MinIO Console |

4. **Apply/Save** the firewall rules

5. **Wait 1-2 minutes** for rules to take effect

6. **Try accessing again**: http://YOUR_IP:3000

## Verify Services Are Running

Before troubleshooting further, make sure services are actually running:

```bash
cd ~/EchoGraph2
sudo docker-compose ps
```

You should see all services with status "Up". If any are "Exit" or missing:

```bash
# View logs to see errors
sudo docker-compose logs

# Restart services
sudo docker-compose down
sudo docker-compose up -d
```

## Check if Ports Are Listening

Verify Docker is listening on the correct ports:

```bash
# Check what's listening on ports
sudo netstat -tlnp | grep -E '(3000|8000|5678|9000|9001)'
```

Expected output should show Docker processes listening on `0.0.0.0:3000`, `0.0.0.0:8000`, etc.

If you see `127.0.0.1:3000` instead of `0.0.0.0:3000`, Docker is only listening on localhost. This means the docker-compose.yml needs adjustment (unlikely with our setup).

## Test from Server

Test if services work locally on the server:

```bash
# Test from the VM itself
curl http://localhost:3000
curl http://localhost:8000/health
curl http://localhost:8000/docs

# Should return HTML or JSON
```

If this works but external access doesn't, it's **definitely a firewall issue**.

## Check Docker Network

Verify Docker containers are using the correct network:

```bash
cd ~/EchoGraph2
sudo docker-compose ps

# Check if containers are on the same network
docker network ls
docker network inspect echograph2_echograph-network
```

## Nuclear Option: Temporarily Disable Firewall (Testing Only!)

**⚠️ WARNING: Only for testing! Re-enable after testing!**

```bash
# Disable UFW temporarily
sudo ufw disable

# Try accessing the site
# If it works now, the issue is definitely firewall rules

# Re-enable UFW (IMPORTANT!)
sudo ufw enable
```

If disabling UFW fixes it, the problem is UFW rules. Re-enable UFW and add the correct rules as shown above.

## Still Not Working?

### Check Contabo VPS Settings

Some Contabo VPS configurations have additional network restrictions:

1. **Check Contabo Control Panel** for:
   - Network settings
   - Security groups
   - Access control lists
   - DDoS protection settings (might block certain ports)

2. **Contact Contabo Support** if needed - they can check for any restrictions on your IP

### Check Your Local Network

Sometimes the issue is on YOUR end:

```bash
# From your local computer (not the server), test connectivity:

# Test if port 3000 is reachable
nc -zv YOUR_SERVER_IP 3000

# Or use telnet
telnet YOUR_SERVER_IP 3000

# Try from different network (mobile hotspot)
```

If it works from mobile hotspot but not your home network, your ISP or router might be blocking the ports.

## Common Solutions Summary

### Solution 1: UFW Firewall (Most Common)
```bash
sudo ufw allow 3000/tcp
sudo ufw allow 8000/tcp
sudo ufw reload
```

### Solution 2: Contabo Control Panel Firewall
- Log into Contabo panel
- Add firewall rules for ports 3000, 8000, 5678, 9000, 9001
- Wait 1-2 minutes

### Solution 3: Restart Services
```bash
cd ~/EchoGraph2
sudo docker-compose restart
```

### Solution 4: Check Services Are Running
```bash
cd ~/EchoGraph2
sudo docker-compose ps
sudo docker-compose logs -f frontend
```

## After Fixing

Once you can access the application:

1. **Access frontend**: http://YOUR_IP:3000
2. **View API docs**: http://YOUR_IP:8000/docs
3. **Set up domain** (recommended): See [deployment-contabo.md](deployment-contabo.md#part-5-production-setup-recommended)
4. **Enable HTTPS**: Use Let's Encrypt for SSL

## Need More Help?

Include this information when asking for help:

```bash
# Run these commands and share output:
sudo ufw status verbose
sudo docker-compose ps
sudo netstat -tlnp | grep -E '(3000|8000)'
curl http://localhost:3000
```

---

**Back to**: [Quick Start Guide](QUICK_START_VM.md) | [Full Deployment Guide](deployment-contabo.md)
