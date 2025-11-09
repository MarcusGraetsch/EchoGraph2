# Restart Instructions for Keycloak Authentication Fix

## Problem Fixed
The Keycloak authentication was showing "Page not found" when accessing from the public IP `http://178.18.254.21:3000` because:
1. Keycloak was configured for `localhost:8080` only
2. The frontend redirect URIs didn't include the public IP
3. The hostname configuration was incorrect

## Changes Made
1. **Created `.env` file** with proper public IP configuration:
   - `KEYCLOAK_PUBLIC_URL=http://178.18.254.21:8080`
   - `KEYCLOAK_HOSTNAME_URL=http://178.18.254.21:8080`
   - `NEXT_PUBLIC_API_URL=http://178.18.254.21:8000`
   - Updated CORS origins

2. **Updated Keycloak realm configuration** (`keycloak/echograph-realm.json`):
   - Added redirect URIs for `http://178.18.254.21:3000/*`
   - Added redirect URIs for `http://178.18.254.21:8000/*`
   - Updated web origins to include public IP
   - Updated post-logout redirect URIs

## How to Apply These Changes

### Step 1: Stop All Services
```bash
docker-compose down
```

### Step 2: Remove Keycloak Data (To Force Realm Reload)
```bash
docker volume rm echograph2_keycloak_data
```
**Note:** This will delete existing Keycloak users. The default admin user will be recreated.

### Step 3: Start Services
```bash
docker-compose up -d
```

### Step 4: Wait for Services to Start
```bash
# Check service status
docker-compose ps

# Watch Keycloak logs
docker-compose logs -f keycloak
```
Wait until you see: `Keycloak ... started`

### Step 5: Initialize Keycloak with the Realm
```bash
# Run the initialization script
./keycloak/init-keycloak.sh
```

### Step 6: Test the Authentication
1. Open browser to: `http://178.18.254.21:3000`
2. Click "Login" button
3. You should see the Keycloak login page (not "Page not found")
4. Login with default credentials:
   - Username: `admin`
   - Password: `admin` (you'll be prompted to change it on first login)

## Alternative: Restart Without Losing Data

If you want to keep existing Keycloak users and just update the configuration:

### Step 1: Access Keycloak Admin Console
```bash
# Open in browser
http://178.18.254.21:8080/admin
```

### Step 2: Update Client Configuration Manually
1. Login with admin credentials
2. Select "echograph" realm
3. Go to "Clients" → "echograph-frontend"
4. Add to "Valid redirect URIs": `http://178.18.254.21:3000/*`
5. Add to "Valid post logout redirect URIs": `http://178.18.254.21:3000/*`
6. Add to "Web origins": `http://178.18.254.21:3000`
7. Click "Save"
8. Repeat for "echograph-api" client with port 8000

### Step 3: Restart Frontend and API Services
```bash
docker-compose restart frontend api keycloak
```

## Troubleshooting

### Still Getting "Page not found"?
Check if Keycloak is accessible:
```bash
curl -I http://178.18.254.21:8080
```
Should return HTTP 200 or 303, not 403.

### Getting CORS errors?
Check that `.env` has:
```env
ALLOWED_ORIGINS=http://178.18.254.21:3000,http://178.18.254.21:8000
```

### Redirect not working?
1. Check browser console for errors
2. Verify `NEXT_PUBLIC_KEYCLOAK_URL` in frontend build:
   ```bash
   docker-compose exec frontend printenv | grep KEYCLOAK
   ```
   Should show: `NEXT_PUBLIC_KEYCLOAK_URL=http://178.18.254.21:8080`

### Need to rebuild frontend?
If environment variables aren't updated:
```bash
docker-compose down frontend
docker-compose build --no-cache frontend
docker-compose up -d frontend
```

## Default Credentials
- **Keycloak Admin**: admin / admin_changeme
- **Default User**: admin / admin (temporary, change on first login)

## Important Notes
1. The `.env` file is now configured for public IP `178.18.254.21`
2. If you need to access from a different IP or domain, update:
   - `KEYCLOAK_PUBLIC_URL`
   - `KEYCLOAK_HOSTNAME_URL`
   - `NEXT_PUBLIC_API_URL`
   - `ALLOWED_ORIGINS`
3. For production, change all default passwords and enable HTTPS
