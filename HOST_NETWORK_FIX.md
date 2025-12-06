# Host Network Mode Volume Mount Fix

## Issue

When using `network_mode: host` in Docker Compose, volume mounts can fail with:

```
error mounting "/opt/xray-cluster/node/certs" to rootfs at "/etc/xray/certs": 
mkdir: read-only file system: unknown
```

## Root Cause

With `network_mode: host`, Docker cannot create directories inside the container's `/etc` directory because it's read-only. The container's filesystem is more restricted in host network mode.

## Solution

Use **bind mounts with explicit type** and mount to non-system directories. Avoid mounting to `/etc` subdirectories.

### Before (Broken)
```yaml
services:
  xray:
    network_mode: host
    volumes:
      - ./xray_config:/etc/xray:ro        # ❌ Mounting to /etc
      - ./certs:/etc/xray/certs           # ❌ Creating subdirectory in /etc
```

### After (Fixed)
```yaml
services:
  xray:
    network_mode: host
    volumes:
      - type: bind
        source: /opt/xray-cluster/node/xray_config/config.json
        target: /etc/xray/config.json     # ✅ Mount file directly
        read_only: true
      - type: bind
        source: /opt/xray-cluster/node/certs
        target: /certs                     # ✅ Mount to root-level directory
        read_only: true
      - type: bind
        source: /opt/xray-cluster/node/logs
        target: /var/log/xray
    command: ["xray", "run", "-config", "/etc/xray/config.json"]
```

## Additional Fixes

### 1. Remove Named Volumes

Named volumes don't work with host network mode. Remove the `volumes:` section at the bottom of docker-compose.yml:

```yaml
# ❌ Remove this
volumes:
  xray_logs:
  caddy_data:
  caddy_config:
```

### 2. Create Directories and Placeholder Files

Ensure all directories and files exist on the host before starting containers:

```bash
mkdir -p /opt/xray-cluster/node/xray_config
mkdir -p /opt/xray-cluster/node/certs
mkdir -p /opt/xray-cluster/node/logs

# Create placeholder certificate files
touch /opt/xray-cluster/node/certs/panel.example.com.crt
touch /opt/xray-cluster/node/certs/panel.example.com.key
touch /opt/xray-cluster/node/certs/node.example.com.crt
touch /opt/xray-cluster/node/certs/node.example.com.key
chmod 600 /opt/xray-cluster/node/certs/*.key
```

### 3. Clean Up Orphaned Containers

Before starting services, clean up any orphaned containers from previous configurations:

```bash
cd /opt/xray-cluster/node
docker-compose down --remove-orphans
docker-compose up -d
```

## Why Host Network Mode?

In SOLO mode, Xray needs to:
1. Bind directly to ports 80 and 443
2. Access the host's network stack
3. Communicate with Caddy on 127.0.0.1:8080

Host network mode is the simplest way to achieve this.

## Important Notes

### Certificate Paths in Xray Config

When mounting certs to `/certs` instead of `/etc/xray/certs`, update your Xray config:

```json
{
  "streamSettings": {
    "tlsSettings": {
      "certificates": [
        {
          "certificateFile": "/certs/node.example.com.crt",
          "keyFile": "/certs/node.example.com.key"
        },
        {
          "certificateFile": "/certs/panel.example.com.crt",
          "keyFile": "/certs/panel.example.com.key"
        }
      ]
    }
  }
}
```

### Placeholder Files

Create empty placeholder files before first run to prevent mount errors:

```bash
touch /opt/xray-cluster/node/certs/panel.example.com.{crt,key}
touch /opt/xray-cluster/node/certs/node.example.com.{crt,key}
```

These will be replaced by real certificates when you run `get-certs.sh`.

## Complete Working Configuration

### docker-compose.yml
```yaml
version: '3.8'

services:
  xray:
    image: ghcr.io/xtls/xray-core:latest
    container_name: xray-node-xray
    restart: unless-stopped
    network_mode: host
    volumes:
      - type: bind
        source: /opt/xray-cluster/node/xray_config/config.json
        target: /etc/xray/config.json
        read_only: true
      - type: bind
        source: /opt/xray-cluster/node/certs
        target: /certs
        read_only: true
      - type: bind
        source: /opt/xray-cluster/node/logs
        target: /var/log/xray
    cap_add:
      - NET_ADMIN
    command: ["xray", "run", "-config", "/etc/xray/config.json"]

  agent:
    build:
      context: .
      dockerfile: Dockerfile.agent
    container_name: xray-node-agent
    restart: unless-stopped
    ports:
      - "127.0.0.1:8081:8080"
    environment:
      - NODE_UUID=${NODE_UUID}
      - CLUSTER_SECRET=${CLUSTER_SECRET}
      - MASTER_DOMAIN=${MASTER_DOMAIN}
      - PANEL_DOMAIN=${PANEL_DOMAIN}
      - NODE_DOMAIN=${NODE_DOMAIN}
      - API_PATH=${API_PATH}
    networks:
      - xray-node-net
    depends_on:
      - xray

networks:
  xray-node-net:
    driver: bridge
```

### Key Changes

1. **Mount config file directly** instead of directory
2. **Mount certs to `/certs`** instead of `/etc/xray/certs`
3. **Use explicit bind mount type** for clarity
4. **Specify command explicitly** to ensure correct config path

## Verification

After fixing, verify the setup:

```bash
# Check if directories exist
ls -la /opt/xray-cluster/node/xray_config
ls -la /opt/xray-cluster/node/certs
ls -la /opt/xray-cluster/node/logs

# Start services
cd /opt/xray-cluster/node
docker-compose down --remove-orphans
docker-compose up -d

# Check status
docker-compose ps

# Check logs
docker-compose logs xray
```

## Expected Output

```
Creating xray-node-xray ... done
Creating xray-node-agent ... done
```

No errors about read-only filesystems or volume mounts.

## Testing

```bash
# Test if Xray is listening on port 443
sudo netstat -tulpn | grep :443

# Test if Xray can write logs
ls -la /opt/xray-cluster/node/logs/

# Test if certificates are accessible
ls -la /opt/xray-cluster/node/certs/
```

---

**Status**: ✅ Fixed  
**Last Updated**: 2024-12-06
