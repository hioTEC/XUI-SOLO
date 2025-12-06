#!/bin/bash

set -e

echo "=== 快速修复 XUI-SOLO ==="
echo ""

# 修复 1: 更新 requirements.txt
echo "1. 修复 Python 依赖版本冲突..."
cat > /opt/xray-cluster/master/requirements.txt << 'EOF'
Flask==3.0.0
Flask-SQLAlchemy==3.1.1
Flask-Login==0.6.3
Flask-Talisman==1.1.0
Werkzeug==3.0.1
psycopg2-binary==2.9.9
redis==5.0.1
requests==2.31.0
python-dotenv==1.0.0
gunicorn==21.2.0
EOF

cp /opt/xray-cluster/master/requirements.txt /opt/xray-cluster/node/requirements.txt
echo "✓ 已更新 requirements.txt"

# 修复 2: 修复 Xray docker-compose 命令
echo ""
echo "2. 修复 Xray 启动命令..."
cd /opt/xray-cluster/node

# 备份
cp docker-compose.yml docker-compose.yml.backup

# 读取环境变量
source .env

# 重新生成 docker-compose.yml
cat > docker-compose.yml << 'EOFCOMPOSE'
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
    command: ["run", "-config", "/etc/xray/config.json"]

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
EOFCOMPOSE

echo "✓ 已修复 Xray 配置"

# 修复 3: 重建并重启服务
echo ""
echo "3. 重建并重启服务..."

# 重建 Web 应用
echo "重建 Web 应用..."
cd /opt/xray-cluster/master
docker-compose build --no-cache web
docker-compose up -d

echo "等待 Web 应用启动..."
sleep 10

# 重启 Xray
echo "重启 Xray..."
cd /opt/xray-cluster/node
docker-compose restart xray

echo ""
echo "=== 修复完成 ==="
echo ""

# 检查服务状态
echo "检查服务状态..."
echo ""
echo "Master 服务:"
cd /opt/xray-cluster/master && docker-compose ps
echo ""
echo "Worker 服务:"
cd /opt/xray-cluster/node && docker-compose ps
echo ""

# 检查 Web 应用日志
echo "Web 应用最新日志:"
cd /opt/xray-cluster/master
docker-compose logs web | tail -20
echo ""

echo "如果 Web 应用显示 'Booting worker'，说明修复成功！"
echo ""
echo "请等待 10 秒后访问："
echo "  https://panel.hiomath.org"
echo ""
echo "或者测试内部连接："
echo "  curl http://127.0.0.1:8080 -H 'Host: panel.hiomath.org'"
