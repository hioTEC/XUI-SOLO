# Host Network Mode Volume Mount Fix

## Issue

When using `network_mode: host` in Docker Compose, volume mounts can fail with:

```
error mounting "/opt/xray-cluster/node/certs" to rootfs at "/etc/xray/certs": 
mkdir: read-only file system: unknown
```

## Root Cause

With `network_mode: host`, Docker has limited control over the container's filesystem, and relative volume paths don't work properly.

## Solution

Use **absolute paths** for all volume mounts when using host network mode.

### Before (Broken)
```yaml
services:
  xray:
    network_mode: host
    volumes:
      - ./xray_config:/etc/xray:ro        # ❌ Relative path
      - xray_logs:/var/log/xray           # ❌ Named volume
      - ./certs:/etc/xray/certs           # ❌ Relative path
```

### After (Fixed)
```yaml
services:
  xray:
    network_mode: host
    volumes:
      - /opt/xray-cluster/node/xray_config:/etc/xray:ro           # ✅ Absolute path
      - /opt/xray-cluster/node/certs:/etc/xray/certs:ro           # ✅ Absolute path
      - /opt/xray-cluster/node/logs:/var/log/xray                 # ✅ Absolute path
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

### 2. Create Directories on Host

Ensure all directories exist on the host before starting containers:

```bash
mkdir -p /opt/xray-cluster/node/xray_config
mkdir -p /opt/xray-cluster/node/certs
mkdir -p /opt/xray-cluster/node/logs
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
      - /opt/xray-cluster/node/xray_config:/etc/xray:ro
      - /opt/xray-cluster/node/certs:/etc/xray/certs:ro
      - /opt/xray-cluster/node/logs:/var/log/xray
    cap_add:
      - NET_ADMIN
    environment:
      - XRAY_LOCATION_ASSET=/usr/local/share/xray

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
