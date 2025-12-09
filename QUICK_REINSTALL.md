# Quick Reinstall Commands

## On Your Local Machine

```bash
# Upload files to server
scp install.sh reinstall-solo.sh root@YOUR_SERVER_IP:/root/
```

## On Your Server

```bash
# Make script executable
chmod +x /root/reinstall-solo.sh

# Run reinstall (interactive - will ask for domains and password)
/root/reinstall-solo.sh
```

That's it! The script will:
- Backup your current config
- Clean up old installation
- Run fresh install with fixed install.sh
- Show you the status

## Alternative: Manual Commands

```bash
# Stop services
cd /opt/xray-cluster/master && docker-compose down -v
cd /opt/xray-cluster/node && docker-compose down -v

# Clean up
docker network rm xray-net
rm -rf /opt/xray-cluster

# Fresh install
cd /root
chmod +x install.sh
./install.sh --solo \
  --panel-domain panel.yourdomain.com \
  --node-domain node.yourdomain.com \
  --admin-password YourPassword
```

## Check Status After Install

```bash
# View running containers
docker ps --filter "name=xray-"

# Check logs
docker logs xray-master-web
docker logs xray-node-xray

# Test panel access
curl -I https://panel.yourdomain.com
```

## If Something Goes Wrong

```bash
# View detailed logs
docker logs xray-master-web --tail 100
docker logs xray-master-postgres --tail 50
docker logs xray-master-redis --tail 50

# Restart a specific service
cd /opt/xray-cluster/master
docker-compose restart web

# Rebuild web service
docker-compose build --no-cache web
docker-compose up -d web
```
