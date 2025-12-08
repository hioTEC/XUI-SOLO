#!/bin/bash

# Fix SOLO mode installation issues
# Run this on your server if you're experiencing 500/404 errors

set -e

INSTALL_DIR="/opt/xray-cluster"

echo "🔧 Fixing SOLO mode installation..."

# Check if running in SOLO mode
if [ ! -d "$INSTALL_DIR/master" ] || [ ! -d "$INSTALL_DIR/node" ]; then
    echo "❌ Error: SOLO mode installation not found at $INSTALL_DIR"
    exit 1
fi

cd $INSTALL_DIR

# Stop services
echo "⏸️  Stopping services..."
cd master && docker-compose down 2>/dev/null || true
cd ../node && docker-compose down 2>/dev/null || true
cd ..

# Fix master web Dockerfile
echo "📝 Fixing master web Dockerfile..."
cat > master/web/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Create log directory
RUN mkdir -p /var/log/xray-master

EXPOSE 5000

# Run with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "app:app"]
EOF

# Copy requirements.txt to web directory
echo "📋 Copying requirements.txt..."
if [ -f "master/requirements.txt" ]; then
    cp master/requirements.txt master/web/requirements.txt
else
    echo "❌ Error: master/requirements.txt not found"
    exit 1
fi

# Fix master docker-compose.yml to use correct build context
echo "🐳 Fixing master docker-compose.yml..."
cd master

# Backup original
cp docker-compose.yml docker-compose.yml.backup

# Update web service to use correct build context and add volumes
sed -i.tmp '/web:/,/networks:/ {
    s|dockerfile: Dockerfile.web|dockerfile: Dockerfile|
    s|context: \.|context: ./web|
    /depends_on:/i\    volumes:\n      - ./app.py:/app/app.py:ro\n      - ./templates:/app/templates:ro
}' docker-compose.yml

rm -f docker-compose.yml.tmp

# Remove old Dockerfile.web if exists
rm -f Dockerfile.web

echo "✅ Master configuration fixed"

cd ..

# Rebuild and restart services
echo "🔄 Rebuilding and starting services..."

cd master
docker-compose build --no-cache web
docker-compose up -d

cd ../node
docker-compose up -d

cd ..

echo ""
echo "✅ Fix completed!"
echo ""
echo "📊 Checking service status..."
sleep 5
docker ps --filter "name=xray-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "📝 To check logs:"
echo "  Master web: docker logs xray-master-web"
echo "  Master caddy: docker logs xray-master-caddy"
echo "  Node xray: docker logs xray-node-xray"
echo ""
echo "🌐 Try accessing your panel now!"
