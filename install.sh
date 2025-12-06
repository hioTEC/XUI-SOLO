#!/bin/bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印彩色消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 未安装，请先安装"
        exit 1
    fi
}

# 检查 Docker 和 Docker Compose
check_docker() {
    check_command docker
    check_command docker-compose
    
    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行，请启动 Docker"
        exit 1
    fi
}

# 生成随机字符串
generate_random_string() {
    local length=$1
    tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w $length | head -n 1
}

# 生成 UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || \
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    fi
}

# 生成 x25519 密钥对
generate_x25519_keypair() {
    python3 -c "
import base64
import os
from cryptography.hazmat.primitives.asymmetric import x25519

private_key = x25519.X25519PrivateKey.generate()
public_key = private_key.public_key()

private_bytes = private_key.private_bytes(
    encoding=encoding.Encoding.Raw,
    format=serialization.PrivateFormat.Raw,
    encryption_algorithm=serialization.NoEncryption()
)

public_bytes = public_key.public_bytes(
    encoding=encoding.Encoding.Raw,
    format=serialization.PublicFormat.Raw
)

print(base64.urlsafe_b64encode(private_bytes).decode('utf-8'))
print(base64.urlsafe_b64encode(public_bytes).decode('utf-8'))
" 2>/dev/null || echo ""
}

# 验证域名解析
check_dns() {
    local domain=$1
    print_info "正在检查域名解析: $domain"
    
    if command -v dig &> /dev/null; then
        local ip=$(dig +short "$domain")
        if [ -z "$ip" ]; then
            print_error "域名 $domain 无法解析，请检查 DNS 配置"
            return 1
        fi
        print_info "域名 $domain 解析到: $ip"
    elif command -v nslookup &> /dev/null; then
        nslookup "$domain" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            print_error "域名 $domain 无法解析，请检查 DNS 配置"
            return 1
        fi
    else
        print_warning "无法验证 DNS 解析，请确保域名已正确解析到服务器 IP"
        read -p "继续安装? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    return 0
}

# 安装 Master 节点
install_master() {
    print_info "开始安装 Master 节点..."
    
    read -p "请输入 Master 面板域名 (如 panel.example.com): " master_domain
    master_domain=$(echo "$master_domain" | tr -d ' ')
    
    if [ -z "$master_domain" ]; then
        print_error "域名不能为空"
        exit 1
    fi
    
    check_dns "$master_domain"
    
    # 生成集群密钥
    CLUSTER_SECRET=$(generate_random_string 32)
    
    print_info "生成集群密钥..."
    echo "CLUSTER_SECRET=$CLUSTER_SECRET"
    echo ""
    print_warning "请妥善保存此集群密钥，安装 Node 节点时需要!"
    echo ""
    
    read -p "按 Enter 继续..."
    
    # 创建目录结构
    print_info "创建目录结构..."
    mkdir -p /opt/xray-cluster/master
    mkdir -p /opt/xray-cluster/master/data
    mkdir -p /opt/xray-cluster/master/caddy_data
    
    # 创建 .env 文件
    cat > /opt/xray-cluster/master/.env << EOF
# Master 配置
MASTER_DOMAIN=$master_domain
CLUSTER_SECRET=$CLUSTER_SECRET
ADMIN_USER=admin
ADMIN_PASSWORD=$(generate_random_string 16)

# 数据库配置
POSTGRES_USER=xray_admin
POSTGRES_PASSWORD=$(generate_random_string 16)
POSTGRES_DB=xray_cluster

# Redis 配置
REDIS_PASSWORD=$(generate_random_string 16)

# Caddy 配置
CADDY_EMAIL=admin@$master_domain
EOF
    
    # 创建 Docker Compose 文件
    cat > /opt/xray-cluster/master/docker-compose.yml << 'EOF'
version: '3.8'

services:
  caddy:
    image: caddy:2-alpine
    container_name: xray-master-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - xray-master-net
    environment:
      - CADDY_EMAIL=${CADDY_EMAIL}

  postgres:
    image: postgres:15-alpine
    container_name: xray-master-postgres
    restart: unless-stopped
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    networks:
      - xray-master-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: xray-master-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - xray-master-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  web:
    build:
      context: ./web
      dockerfile: Dockerfile
    container_name: xray-master-web
    restart: unless-stopped
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./app.py:/app/app.py:ro
      - ./requirements.txt:/app/requirements.txt:ro
      - ./templates:/app/templates:ro
      - ./static:/app/static:ro
    environment:
      - MASTER_DOMAIN=${MASTER_DOMAIN}
      - CLUSTER_SECRET=${CLUSTER_SECRET}
      - ADMIN_USER=${ADMIN_USER}
      - ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0
    networks:
      - xray-master-net

networks:
  xray-master-net:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  caddy_data:
  caddy_config:
EOF
    
    # 创建 Caddyfile
    cat > /opt/xray-cluster/master/Caddyfile << EOF
${MASTER_DOMAIN} {
    encode gzip
    
    # 基本认证
    basicauth {
        ${ADMIN_USER} ${ADMIN_PASSWORD_HASH}
    }
    
    reverse_proxy web:8080 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
    
    log {
        output file /data/access.log {
            roll_size 10MiB
            roll_keep 5
        }
    }
}
EOF
    
    # 创建 Web 应用目录
    mkdir -p /opt/xray-cluster/master/web
    mkdir -p /opt/xray-cluster/master/templates
    mkdir -p /opt/xray-cluster/master/static
    
    # 创建 Web Dockerfile
    cat > /opt/xray-cluster/master/web/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "app:app"]
EOF
    
    print_info "启动 Master 服务..."
    cd /opt/xray-cluster/master
    docker-compose up -d
    
    print_success "Master 节点安装完成!"
    print_info "访问地址: https://${master_domain}"
    print_info "管理员账号: ${ADMIN_USER}"
    print_info "管理员密码: ${ADMIN_PASSWORD}"
}

# 安装 Node 节点
install_node() {
    print_info "开始安装 Node 节点..."
    
    read -p "请输入集群密钥: " cluster_secret
    cluster_secret=$(echo "$cluster_secret" | tr -d ' ')
    
    if [ -z "$cluster_secret" ]; then
        print_error "集群密钥不能为空"
        exit 1
    fi
    
    read -p "请输入 Master 面板域名: " master_domain
    master_domain=$(echo "$master_domain" | tr -d ' ')
    
    read -p "请输入本节点域名: " node_domain
    node_domain=$(echo "$node_domain" | tr -d ' ')
    
    if [ -z "$node_domain" ]; then
        print_error "节点域名不能为空"
        exit 1
    fi
    
    check_dns "$node_domain"
    
    # 生成节点 UUID 和密钥
    NODE_UUID=$(generate_uuid)
    X25519_KEYS=$(generate_x25519_keypair)
    
    if [ -z "$X25519_KEYS" ]; then
        print_warning "无法生成 x25519 密钥对，使用随机字符串代替"
        X25519_PRIVATE_KEY=$(generate_random_string 32)
        X25519_PUBLIC_KEY=$(generate_random_string 32)
    else
        X25519_PRIVATE_KEY=$(echo "$X25519_KEYS" | head -n1)
        X25519_PUBLIC_KEY=$(echo "$X25519_KEYS" | tail -n1)
    fi
    
    # 生成安全的 API 路径
    API_PATH=$(echo -n "${cluster_secret}:$(date +%s):${node_uuid}" | sha256sum | cut -c1-16)
    
    # 创建目录结构
    print_info "创建目录结构..."
    mkdir -p /opt/xray-cluster/node
    mkdir -p /opt/xray-cluster/node/xray_config
    mkdir -p /opt/xray-cluster/node/caddy_data
    
    # 创建 .env 文件
    cat > /opt/xray-cluster/node/.env << EOF
# Node 配置
NODE_DOMAIN=$node_domain
MASTER_DOMAIN=$master_domain
CLUSTER_SECRET=$cluster_secret
NODE_UUID=$NODE_UUID
X25519_PRIVATE_KEY=$X25519_PRIVATE_KEY
X25519_PUBLIC_KEY=$X25519_PUBLIC_KEY
API_PATH=$API_PATH

# Hysteria2 配置
HYSTERIA_PORT=50000
HYSTERIA_PASSWORD=$(generate_random_string 16)

# Caddy 配置
CADDY_EMAIL=admin@$node_domain
EOF
    
    # 创建 Xray 配置文件
    cat > /opt/xray-cluster/node/xray_config/config.json << 'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "dns": {
    "servers": [
      "8.8.8.8",
      "1.1.1.1"
    ]
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${NODE_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 80,
            "xver": 1
          },
          {
            "path": "/${API_PATH}",
            "dest": 8080,
            "xver": 1
          },
          {
            "path": "/${SPLIT_HTTP_PATH}",
            "dest": 10000,
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "rejectUnknownSni": true,
          "minVersion": "1.2",
          "cipherSuites": "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256:TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384:TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
          "certificates": [
            {
              "certificateFile": "/etc/xray/cert.pem",
              "keyFile": "/etc/xray/key.pem"
            }
          ]
        },
        "tcpSettings": {
          "acceptProxyProtocol": true
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      },
      "tag": "vless-in"
    },
    {
      "port": 10000,
      "protocol": "xhttp",
      "settings": {
        "timeout": 300,
        "accounts": [
          {
            "username": "user",
            "password": "${SPLIT_HTTP_PASSWORD}"
          }
        ]
      },
      "tag": "split-http-in"
    },
    {
      "port": ${HYSTERIA_PORT},
      "protocol": "hysteria2",
      "settings": {
        "users": [
          {
            "name": "default",
            "password": "${HYSTERIA_PASSWORD}"
          }
        ],
        "obfs": {
          "type": "salamander",
          "password": "${HYSTERIA_OBFS_PASSWORD}"
        }
      },
      "streamSettings": {
        "network": "udp",
        "security": "none"
      },
      "tag": "hysteria2-in"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "block"
      }
    ]
  },
  "policy": {
    "levels": {
      "0": {
        "handshake": 4,
        "connIdle": 300,
        "uplinkOnly": 2,
        "downlinkOnly": 5,
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    }
  },
  "stats": {},
  "reverse": {}
}
EOF
    
    # 创建 Docker Compose 文件
    cat > /opt/xray-cluster/node/docker-compose.yml << 'EOF'
version: '3.8'

services:
  caddy:
    image: caddy:2-alpine
    container_name: xray-node-caddy
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
      - ./ssl:/etc/xray:ro
    networks:
      - xray-node-net
    environment:
      - CADDY_EMAIL=${CADDY_EMAIL}
    command: ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]

  xray:
    image: ghcr.io/xtls/xray-core:latest
    container_name: xray-node-xray
    restart: unless-stopped
    ports:
      - "443:443"
      - "443:443/udp"
      - "${HYSTERIA_PORT}:${HYSTERIA_PORT}/udp"
    volumes:
      - ./xray_config/config.json:/etc/xray/config.json:ro
      - ./ssl:/etc/xray:ro
      - xray_logs:/var/log/xray
    cap_add:
      - NET_ADMIN
      - SYS_RESOURCE
    sysctls:
      - net.core.rmem_max=2500000
    networks:
      - xray-node-net
    depends_on:
      - caddy

  agent:
    build:
      context: ./agent
      dockerfile: Dockerfile
    container_name: xray-node-agent
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./xray_config/config.json:/app/config/config.json:ro
      - ./agent.py:/app/agent.py:ro
      - ./requirements.txt:/app/requirements.txt:ro
    environment:
      - NODE_UUID=${NODE_UUID}
      - CLUSTER_SECRET=${CLUSTER_SECRET}
      - MASTER_DOMAIN=${MASTER_DOMAIN}
      - API_PATH=${API_PATH}
      - SPLIT_HTTP_PATH=${SPLIT_HTTP_PATH:-/http}
      - SPLIT_HTTP_PASSWORD=${SPLIT_HTTP_PASSWORD}
      - HYSTERIA_PORT=${HYSTERIA_PORT}
      - HYSTERIA_PASSWORD=${HYSTERIA_PASSWORD}
      - HYSTERIA_OBFS_PASSWORD=${HYSTERIA_OBFS_PASSWORD}
    networks:
      - xray-node-net
    depends_on:
      - xray

networks:
  xray-node-net:
    driver: bridge

volumes:
  xray_logs:
  caddy_data:
  caddy_config:
EOF
    
    # 创建 Caddyfile
    cat > /opt/xray-cluster/node/Caddyfile << EOF
:80 {
    encode gzip
    
    # API 路径转发到 Agent
    handle_path /${API_PATH}/* {
        reverse_proxy agent:8080
    }
    
    # 其他请求返回 404
    respond "404 Not Found" 404
}
EOF
    
    # 创建 SSL 证书目录（Caddy 会自动管理）
    mkdir -p /opt/xray-cluster/node/ssl
    
    # 创建 Agent 目录
    mkdir -p /opt/xray-cluster/node/agent
    
    # 创建 Agent Dockerfile
    cat > /opt/xray-cluster/node/agent/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["python", "agent.py"]
EOF
    
    print_info "启动 Node 服务..."
    cd /opt/xray-cluster/node
    docker-compose up -d
    
    print_success "Node 节点安装完成!"
    print_info "节点域名: ${node_domain}"
    print_info "API 路径: /${API_PATH}"
    print_info "Hysteria2 端口: ${HYSTERIA_PORT}"
}

# 安装 SOLO 模式（Master + 本地 Worker）
install_solo() {
    print_info "开始 SOLO 模式安装（Master + 本地 Worker 一体化部署）..."
    echo ""
    
    read -p "请输入域名 (如 example.com): " domain
    domain=$(echo "$domain" | tr -d ' ')
    
    if [ -z "$domain" ]; then
        print_error "域名不能为空"
        exit 1
    fi
    
    check_dns "$domain"
    
    # 生成集群密钥
    CLUSTER_SECRET=$(generate_random_string 32)
    ADMIN_PASSWORD=$(generate_random_string 16)
    POSTGRES_PASSWORD=$(generate_random_string 16)
    REDIS_PASSWORD=$(generate_random_string 16)
    
    print_info "生成安全密钥..."
    echo ""
    
    # 生成节点 UUID 和密钥
    NODE_UUID=$(generate_uuid)
    X25519_KEYS=$(generate_x25519_keypair)
    
    if [ -z "$X25519_KEYS" ]; then
        print_warning "无法生成 x25519 密钥对，使用随机字符串代替"
        X25519_PRIVATE_KEY=$(generate_random_string 32)
        X25519_PUBLIC_KEY=$(generate_random_string 32)
    else
        X25519_PRIVATE_KEY=$(echo "$X25519_KEYS" | head -n1)
        X25519_PUBLIC_KEY=$(echo "$X25519_KEYS" | tail -n1)
    fi
    
    # 生成安全的 API 路径
    API_PATH=$(echo -n "${CLUSTER_SECRET}:$(date +%s):${NODE_UUID}" | sha256sum | cut -c1-16)
    HYSTERIA_PASSWORD=$(generate_random_string 16)
    
    # 创建目录结构
    print_info "创建目录结构..."
    mkdir -p /opt/xray-cluster/master
    mkdir -p /opt/xray-cluster/master/data
    mkdir -p /opt/xray-cluster/master/caddy_data
    mkdir -p /opt/xray-cluster/master/web
    mkdir -p /opt/xray-cluster/master/templates
    mkdir -p /opt/xray-cluster/master/static
    
    mkdir -p /opt/xray-cluster/node
    mkdir -p /opt/xray-cluster/node/xray_config
    mkdir -p /opt/xray-cluster/node/caddy_data
    mkdir -p /opt/xray-cluster/node/agent
    mkdir -p /opt/xray-cluster/node/ssl
    
    # 复制应用文件
    print_info "复制应用文件..."
    cp -r master/* /opt/xray-cluster/master/ 2>/dev/null || true
    cp -r node/* /opt/xray-cluster/node/ 2>/dev/null || true
    cp requirements.txt /opt/xray-cluster/master/ 2>/dev/null || true
    cp requirements.txt /opt/xray-cluster/node/ 2>/dev/null || true
    
    # 创建 Master .env 文件
    cat > /opt/xray-cluster/master/.env << EOF
# Master 配置
MASTER_DOMAIN=$domain
CLUSTER_SECRET=$CLUSTER_SECRET
ADMIN_USER=admin
ADMIN_PASSWORD=$ADMIN_PASSWORD

# 数据库配置
POSTGRES_USER=xray_admin
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=xray_cluster

# Redis 配置
REDIS_PASSWORD=$REDIS_PASSWORD

# Caddy 配置
CADDY_EMAIL=admin@$domain
EOF
    
    # 创建 Node .env 文件
    cat > /opt/xray-cluster/node/.env << EOF
# Node 配置
NODE_DOMAIN=$domain
MASTER_DOMAIN=$domain
CLUSTER_SECRET=$CLUSTER_SECRET
NODE_UUID=$NODE_UUID
X25519_PRIVATE_KEY=$X25519_PRIVATE_KEY
X25519_PUBLIC_KEY=$X25519_PUBLIC_KEY
API_PATH=$API_PATH

# Hysteria2 配置
HYSTERIA_PORT=50000
HYSTERIA_PASSWORD=$HYSTERIA_PASSWORD

# Caddy 配置
CADDY_EMAIL=admin@$domain
EOF
    
    # 启动 Master 服务
    print_info "启动 Master 控制面板..."
    cd /opt/xray-cluster/master
    docker-compose up -d
    
    # 等待 Master 启动
    print_info "等待 Master 服务启动..."
    sleep 10
    
    # 启动 Node 服务
    print_info "启动本地 Worker 节点..."
    cd /opt/xray-cluster/node
    docker-compose up -d
    
    # 等待服务完全启动
    print_info "等待服务完全启动..."
    sleep 5
    
    # 显示安装信息
    echo ""
    echo "========================================"
    print_success "SOLO 模式安装完成！"
    echo "========================================"
    echo ""
    print_info "访问信息:"
    echo "  控制面板: https://${domain}"
    echo "  管理员账号: admin"
    echo "  管理员密码: ${ADMIN_PASSWORD}"
    echo ""
    print_info "集群信息:"
    echo "  集群密钥: ${CLUSTER_SECRET}"
    echo "  节点UUID: ${NODE_UUID}"
    echo ""
    print_info "本地 Worker 已自动部署并注册"
    echo "  节点域名: ${domain}"
    echo "  API路径: /${API_PATH}"
    echo "  Hysteria2端口: 50000"
    echo ""
    print_warning "重要提示:"
    echo "  1. 请妥善保存上述信息"
    echo "  2. 首次登录后请立即修改管理员密码"
    echo "  3. 确保防火墙已开放 80, 443, 50000 端口"
    echo "  4. 等待 1-2 分钟让 Caddy 自动获取 SSL 证书"
    echo ""
    print_info "添加更多 Worker 节点时使用集群密钥"
    echo ""
    
    # 保存信息到文件
    cat > /opt/xray-cluster/INSTALL_INFO.txt << EOF
SOLO 模式安装信息
安装时间: $(date)

访问信息:
  控制面板: https://${domain}
  管理员账号: admin
  管理员密码: ${ADMIN_PASSWORD}

集群信息:
  集群密钥: ${CLUSTER_SECRET}
  节点UUID: ${NODE_UUID}

本地 Worker:
  节点域名: ${domain}
  API路径: /${API_PATH}
  Hysteria2端口: 50000
  Hysteria2密码: ${HYSTERIA_PASSWORD}

数据库:
  用户: xray_admin
  密码: ${POSTGRES_PASSWORD}
  数据库: xray_cluster

Redis:
  密码: ${REDIS_PASSWORD}
EOF
    
    print_success "安装信息已保存到: /opt/xray-cluster/INSTALL_INFO.txt"
    echo ""
}

# 主菜单
main_menu() {
    clear
    echo "========================================"
    echo "    Xray 集群管理系统安装程序"
    echo "========================================"
    echo ""
    echo "请选择安装类型:"
    echo "1. SOLO 模式 (推荐) - Master + 本地 Worker 一体化"
    echo "2. 安装 Master 节点 (控制面板)"
    echo "3. 安装 Worker 节点 (代理节点)"
    echo "4. 查看服务状态"
    echo "5. 卸载服务"
    echo "6. 退出"
    echo ""
    
    read -p "请输入选择 (1-6): " choice
    
    case $choice in
        1)
            check_docker
            install_solo
            ;;
        2)
            check_docker
            install_master
            ;;
        3)
            check_docker
            install_node
            ;;
        4)
            check_service_status
            ;;
        5)
            uninstall_service
            ;;
        6)
            echo "退出安装程序"
            exit 0
            ;;
        *)
            print_error "无效的选择"
            sleep 2
            main_menu
            ;;
    esac
}

# 检查服务状态
check_service_status() {
    if [ -d "/opt/xray-cluster/master" ]; then
        print_info "Master 服务状态:"
        cd /opt/xray-cluster/master && docker-compose ps
    fi
    
    if [ -d "/opt/xray-cluster/node" ]; then
        print_info "Node 服务状态:"
        cd /opt/xray-cluster/node && docker-compose ps
    fi
}

# 卸载服务
uninstall_service() {
    read -p "确定要卸载吗？这将删除所有数据 (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    if [ -d "/opt/xray-cluster/master" ]; then
        print_info "停止 Master 服务..."
        cd /opt/xray-cluster/master && docker-compose down -v
    fi
    
    if [ -d "/opt/xray-cluster/node" ]; then
        print_info "停止 Node 服务..."
        cd /opt/xray-cluster/node && docker-compose down -v
    fi
    
    print_info "删除安装目录..."
    rm -rf /opt/xray-cluster
    
    print_success "卸载完成"
}

# 主函数
main() {
    if [ "$(id -u)" != "0" ]; then
        print_error "请使用 root 或 sudo 运行此脚本"
        exit 1
    fi
    
    # 解析命令行参数
    if [ "$1" = "--solo" ]; then
        check_docker
        install_solo
    elif [ "$1" = "--master" ]; then
        check_docker
        install_master
    elif [ "$1" = "--node" ]; then
        check_docker
        install_node
    elif [ "$1" = "--uninstall" ]; then
        uninstall_service
    else
        main_menu
    fi
}

# 运行主函数
main "$@"