# SOLO Mode Fix Guide

## What Went Wrong

The previous changes to install.sh broke SOLO mode in several ways:

1. **Docker Compose Variable Expansion**: Used single quotes `'EOFCOMPOSE'` which prevented environment variables from being substituted
2. **Wrong Build Context**: Referenced `Dockerfile.web` in root instead of using existing `web/Dockerfile`
3. **Dockerfile Issues**: Had incorrect relative paths (`../app.py`) that don't work with Docker build context
4. **Missing Files**: requirements.txt wasn't copied to web directory for Docker build

## Symptoms

- ✗ Can login but get 500 errors
- ✗ 404 errors when navigating panel
- ✗ Node shows as offline
- ✗ Web container fails to build or crashes

## Solution

### For New Installations

Just use the updated `install.sh` - all issues are fixed.

### For Existing Broken Installations

Run the fix script on your server:

```bash
# Download the fix script
wget https://raw.githubusercontent.com/YOUR_REPO/main/fix-solo-mode.sh

# Make it executable
chmod +x fix-solo-mode.sh

# Run it (requires sudo/root)
sudo ./fix-solo-mode.sh
```

### Manual Fix (if script doesn't work)

1. **Stop services**:
```bash
cd /opt/xray-cluster/master
docker-compose down
cd ../node
docker-compose down
```

2. **Fix web Dockerfile**:
```bash
cd /opt/xray-cluster/master/web
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p /var/log/xray-master

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "app:app"]
EOF
```

3. **Copy requirements.txt**:
```bash
cp /opt/xray-cluster/master/requirements.txt /opt/xray-cluster/master/web/requirements.txt
```

4. **Update master docker-compose.yml**:

Edit `/opt/xray-cluster/master/docker-compose.yml` and change the web service:

```yaml
  web:
    build:
      context: ./web
      dockerfile: Dockerfile
    container_name: xray-master-web
    restart: unless-stopped
    volumes:
      - ./app.py:/app/app.py:ro
      - ./templates:/app/templates:ro
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      - MASTER_DOMAIN=${MASTER_DOMAIN}
      - CLUSTER_SECRET=${CLUSTER_SECRET}
      - ADMIN_USER=${ADMIN_USER}
      - ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0
    networks:
      - xray-net
```

5. **Rebuild and restart**:
```bash
cd /opt/xray-cluster/master
docker-compose build --no-cache web
docker-compose up -d

cd ../node
docker-compose up -d
```

6. **Check status**:
```bash
docker ps --filter "name=xray-"
docker logs xray-master-web
```

## Verification

After the fix, you should see:

- ✓ Panel loads without 500 errors
- ✓ All pages work (dashboard, nodes, settings)
- ✓ Node shows as online
- ✓ No errors in `docker logs xray-master-web`

## What Was Fixed in install.sh

1. **Variable Escaping**: Changed from `'EOFCOMPOSE'` to `EOFCOMPOSE` with `\${VAR}` escaping
2. **Build Context**: Changed from `context: .` + `dockerfile: Dockerfile.web` to `context: ./web` + `dockerfile: Dockerfile`
3. **Volume Mounts**: Added app.py and templates as read-only volumes for easier updates
4. **Dockerfile**: Removed relative paths, fixed port to 5000
5. **Requirements**: Added step to copy requirements.txt to web directory

## Prevention

The root cause was using single quotes in heredoc which prevented bash variable expansion. The fix uses unquoted heredoc with escaped variables (`\${VAR}`) so Docker Compose can read them from the .env file at runtime.
