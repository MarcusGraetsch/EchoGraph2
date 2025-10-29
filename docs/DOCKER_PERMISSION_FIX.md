# Quick Fix: Docker Permission Error

If you got a Docker permission error when running the deployment script, here's the quick fix:

## The Issue

When you're added to the `docker` group, the changes don't take effect until you log out and back in, or start a new shell session.

## Solution 1: Activate Docker Group (Fastest)

Run this command in your current session:

```bash
newgrp docker
```

Then re-run the deployment:

```bash
cd ~/EchoGraph2
./scripts/deploy-contabo.sh
```

The script will now work because Docker permissions are active.

## Solution 2: Log Out and Back In

```bash
# Log out
exit

# SSH back in
ssh echograph@your-server-ip

# Run deployment
cd ~/EchoGraph2
./scripts/deploy-contabo.sh
```

## Solution 3: Use Sudo (Temporary)

If you just want to get it running quickly:

```bash
cd ~/EchoGraph2
sudo docker-compose up -d
```

Then later, log out and back in to use Docker without sudo.

## Verify Docker Works

Test if Docker works without sudo:

```bash
docker ps
```

If this works without errors, you're good to go!

## Alternative: Manual Deployment Steps

If the script keeps failing, you can run these commands manually:

```bash
cd ~/EchoGraph2

# Configure environment
cp .env.example .env
nano .env  # Edit with your settings

# Start services with sudo
sudo docker-compose up -d

# Wait 30 seconds
sleep 30

# Check status
sudo docker-compose ps

# Initialize database
sudo docker-compose exec -T api python -c "from database import init_db; init_db()"
```

## After Fix

Once Docker permissions are working:
- Run `docker ps` (without sudo) to verify
- Use `docker-compose` commands without sudo
- The deployment script will work normally

---

**Back to:** [Quick Start Guide](QUICK_START_VM.md)
