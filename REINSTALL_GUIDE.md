# SOLO Mode Reinstall Guide

## Quick Reinstall (Recommended)

Use the automated reinstall script:

```bash
# Upload the updated files to your server
scp install.sh reinstall-solo.sh root@your-server:/root/

# SSH to your server
ssh root@your-server

# Run the reinstall script
cd /root
chmod +x reinstall-solo.sh
./reinstall-solo.sh
```

The script will:
1. ✅ Backup your existing configuration (.env files)
2. ✅ Stop and remove all services
3. ✅ Clean up old installation
4. ✅ Optionally reuse your previous settings
5. ✅ Run fresh installation with fixed install.sh
6. ✅ Verify services are running

## Manual Reinstall

If you prefer to do it manually:

### Step 1: Backup Configuration (Optional)

```bash
# Backup your .env files
mkdir -p /tmp/xray-backup
cp /opt/xray-cluster/master/.env /tmp/xray-backup/master.env
cp /opt/xray-cluster/node/.env /tmp/xray-backup/node.env
```

### Step 2: Uninstall

```bash
# Stop services
cd /opt/xray-cluster/master && docker-compose down -v
cd /opt/xray-cluster/node && docker-compose down -v

# Remove network
docker network rm xray-net

# Remove installation
rm -rf /opt/xray-cluster
```

### Step 3: Upload Updated Files

```bash
# From your local machine
scp install.sh root@your-server:/root/
```

### Step 4: Fresh Install

```bash
# On your server
cd /root
chmod +x install.sh

# Run SOLO mode installation
./install.sh --solo \
  --panel-domain panel.yourdomain.com \
  --node-domain node.yourdomain.com \
  --admin-password YourSecurePassword
```

### Step 5: Verify

```bash
# Check running containers
docker ps --filter "name=xray-"

# Check logs
docker logs xray-master-web
docker logs xray-master-caddy
docker logs xray-node-xray

# Test access
curl -I https://panel.yourdomain.com
```

## What's Fixed in Updated install.sh

1. ✅ **Docker Compose Variable Expansion**
   - Changed from single quotes to proper escaping
   - Environment variables now work correctly

2. ✅ **Web Service Build**
   - Uses correct build context: `./web`
   - Uses existing Dockerfile
   - Mounts app.py and templates as volumes

3. ✅ **Web Dockerfile**
   - Fixed paths (no more `../` references)
   - Correct port (5000)
   - Proper build context

4. ✅ **Requirements.txt**
   - Automatically copied to web directory
   - Available for Docker build

5. ✅ **Both Modes Fixed**
   - Regular Node mode
   - SOLO mode

## Troubleshooting

### Services won't start

```bash
# Check Docker daemon
systemctl status docker

# Check logs
docker logs xray-master-web
docker logs xray-master-postgres
docker logs xray-master-redis
```

### Database connection errors

```bash
# Wait for postgres to be ready
docker logs xray-master-postgres

# Check if postgres is healthy
docker ps --filter "name=postgres"
```

### Web service crashes

```bash
# Check if requirements.txt exists
ls -la /opt/xray-cluster/master/web/requirements.txt

# Check if app.py is mounted
docker exec xray-master-web ls -la /app/

# Rebuild web service
cd /opt/xray-cluster/master
docker-compose build --no-cache web
docker-compose up -d web
```

### Port conflicts

```bash
# Check what's using port 443
netstat -tlnp | grep :443

# Check what's using port 80
netstat -tlnp | grep :80
```

### Certificate issues

```bash
# Check certificates
ls -la /opt/xray-cluster/node/certs/

# Check Xray logs
docker logs xray-node-xray
```

## Post-Installation Checklist

- [ ] Panel accessible at https://panel.yourdomain.com
- [ ] Can login with admin credentials
- [ ] Dashboard loads without errors
- [ ] Node shows as online
- [ ] Can view node details
- [ ] No 500 or 404 errors
- [ ] All Docker containers running
- [ ] Certificates valid

## Getting Help

If you encounter issues:

1. Check logs: `docker logs xray-master-web`
2. Check service status: `docker ps --filter "name=xray-"`
3. Verify .env files have correct values
4. Ensure domains point to your server IP
5. Check firewall allows ports 80, 443

## Rollback

If something goes wrong and you have a backup:

```bash
# Stop new installation
cd /opt/xray-cluster/master && docker-compose down -v
cd /opt/xray-cluster/node && docker-compose down -v
rm -rf /opt/xray-cluster

# Restore from backup
# (You'll need to have saved the entire directory, not just .env files)
```

## Clean Start (Nuclear Option)

If everything is broken:

```bash
# Stop all xray containers
docker stop $(docker ps -q --filter "name=xray-")

# Remove all xray containers
docker rm $(docker ps -aq --filter "name=xray-")

# Remove volumes
docker volume rm $(docker volume ls -q | grep xray)

# Remove network
docker network rm xray-net

# Remove installation
rm -rf /opt/xray-cluster

# Start fresh
./install.sh --solo --panel-domain ... --node-domain ... --admin-password ...
```
