
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

# 检查并安装必要工具
check_and_install_tools() {
    local tools=("curl" "git" "openssl")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_warning "检测到缺失的工具: ${missing_tools[*]}"
        print_info "正在自动安装..."
        
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
        else
            print_error "无法检测操作系统"
            return 1
        fi
        
        if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
            apt-get update
            for tool in "${missing_tools[@]}"; do
                print_info "安装 $tool..."
                apt-get install -y "$tool"
            done
        elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
            for tool in "${missing_tools[@]}"; do
                print_info "安装 $tool..."
                yum install -y "$tool"
            done
        else
            print_error "不支持的操作系统: $OS"
            print_info "请手动安装: ${missing_tools[*]}"
            return 1
        fi
        
        print_success "工具安装完成"
    fi
    
    return 0
}

# 安装 Docker
install_docker() {
    print_info "检测到 Docker 未安装，开始安装..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        print_error "无法检测操作系统"
        exit 1
    fi
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt-get update
        apt-get install -y ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        print_error "不支持的操作系统: $OS"
        print_info "请手动安装 Docker: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker 安装完成"
}

# 检查 Docker 和 Docker Compose
check_docker() {
    check_and_install_tools
    
    if ! command -v docker &> /dev/null; then
        install_docker
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        print_warning "Docker Compose 未安装，正在安装..."
        
        if docker --version | grep -q "Docker version"; then
            print_info "安装 Docker Compose V2 插件..."
            
            mkdir -p /usr/local/lib/docker/cli-plugins
            
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
            curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
                -o /usr/local/lib/docker/cli-plugins/docker-compose
            chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
            
            if ! command -v docker-compose &> /dev/null; then
                cat > /usr/local/bin/docker-compose << 'EOFDC'
docker compose "$@"
EOFDC
                chmod +x /usr/local/bin/docker-compose
            fi
            
            print_success "Docker Compose V2 安装完成"
        else
            print_error "Docker 未正确安装"
            exit 1
        fi
    fi
    
    if command -v docker-compose &> /dev/null; then
        print_success "docker-compose 可用: $(docker-compose version --short 2>/dev/null || echo 'V2')"
    elif docker compose version &> /dev/null 2>&1; then
        print_success "docker compose 可用: $(docker compose version --short 2>/dev/null || echo 'V2')"
    else
        print_error "Docker Compose 安装失败"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行，正在启动..."
        systemctl start docker
        sleep 2
        if ! docker info &> /dev/null; then
            print_error "Docker 服务启动失败"
            exit 1
        fi
    fi
    
    print_success "Docker 环境检查通过"
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
    if command -v xray &> /dev/null; then
        local keys=$(xray x25519 2>/dev/null)
        if [ -n "$keys" ]; then
            echo "$keys" | grep "Private key:" | awk '{print $3}'
            echo "$keys" | grep "Public key:" | awk '{print $3}'
            return 0
        fi
    fi
    
    if command -v openssl &> /dev/null; then
        local private_key=$(openssl rand -base64 32)
        local public_key=$(openssl rand -base64 32)
        echo "$private_key"
        echo "$public_key"
        return 0
    fi
    
    python3 -c "
import base64
import os
try:
    from cryptography.hazmat.primitives.asymmetric import x25519
    from cryptography.hazmat.primitives import serialization
    
    private_key = x25519.X25519PrivateKey.generate()
    public_key = private_key.public_key()
    
    private_bytes = private_key.private_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PrivateFormat.Raw,
        encryption_algorithm=serialization.NoEncryption()
    )
    
    public_bytes = public_key.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw
    )
    
    print(base64.urlsafe_b64encode(private_bytes).decode('utf-8'))
    print(base64.urlsafe_b64encode(public_bytes).decode('utf-8'))
except ImportError:
    print(base64.urlsafe_b64encode(os.urandom(32)).decode('utf-8'))
    print(base64.urlsafe_b64encode(os.urandom(32)).decode('utf-8'))
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
    
    CLUSTER_SECRET=$(generate_random_string 32)
    
    print_info "生成集群密钥..."
    echo "CLUSTER_SECRET=$CLUSTER_SECRET"
    echo ""
    print_warning "请妥善保存此集群密钥，安装 Node 节点时需要!"
    echo ""
    
    read -p "按 Enter 继续..."
    
    print_info "创建目录结构..."
    mkdir -p /opt/xray-cluster/master
    mkdir -p /opt/xray-cluster/master/data
    mkdir -p /opt/xray-cluster/master/caddy_data
    
    cat > /opt/xray-cluster/master/.env << EOF
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
    
    cat > /opt/xray-cluster/master/Caddyfile << EOF
${MASTER_DOMAIN} {
    encode gzip
    
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
    
    mkdir -p /opt/xray-cluster/master/web
    mkdir -p /opt/xray-cluster/master/templates
    mkdir -p /opt/xray-cluster/master/static
    
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
    
    API_PATH=$(echo -n "${cluster_secret}:$(date +%s):${node_uuid}" | sha256sum | cut -c1-16)
    
    print_info "创建目录结构..."
    mkdir -p /opt/xray-cluster/node
    mkdir -p /opt/xray-cluster/node/xray_config
    mkdir -p /opt/xray-cluster/node/caddy_data
    
    cat > /opt/xray-cluster/node/.env << EOF
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
    
    cat > /opt/xray-cluster/node/Caddyfile << EOF
:80 {
    encode gzip
    
    handle_path /${API_PATH}/* {
        reverse_proxy agent:8080
    }
    
    respond "404 Not Found" 404
}
EOF
    
    mkdir -p /opt/xray-cluster/node/ssl
    
    mkdir -p /opt/xray-cluster/node/agent
    
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
    local panel_domain="$1"
    local node_domain="$2"
    
    print_info "开始 SOLO 模式安装（Master + 本地 Worker 一体化部署）..."
    echo ""
    print_info "SOLO 模式使用 Xray 作为网关，统一管理 443 端口"
    echo ""
    
    local KEEP_CONFIG=false
    if [ -f "/opt/xray-cluster/INSTALL_INFO.txt" ]; then
        print_warning "检测到已有安装"
        if [ -t 0 ]; then
            read -p "是否保留现有配置？(y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                KEEP_CONFIG=true
                print_info "将保留现有配置和数据"
            fi
        fi
    fi
    
    if [ "$KEEP_CONFIG" = true ] && [ -f "/opt/xray-cluster/master/.env" ]; then
        if [ -z "$panel_domain" ]; then
            panel_domain=$(grep "^PANEL_DOMAIN=" /opt/xray-cluster/master/.env | cut -d'=' -f2)
        fi
        if [ -z "$node_domain" ] && [ -f "/opt/xray-cluster/node/.env" ]; then
            node_domain=$(grep "^NODE_DOMAIN=" /opt/xray-cluster/node/.env | cut -d'=' -f2)
        fi
        if [ -n "$panel_domain" ] && [ -n "$node_domain" ]; then
            print_info "从现有配置读取域名: $panel_domain, $node_domain"
        fi
    fi
    
    if [ -z "$panel_domain" ]; then
        if [ -t 0 ]; then
            read -p "请输入管理面板域名 (如 panel.example.com): " panel_domain
            read -p "请输入节点域名 (如 node.example.com): " node_domain
        else
            print_error "检测到通过管道运行，必须提供域名参数"
            print_info "使用方法: curl -fsSL ... | sudo bash -s -- --solo --panel panel.com --node-domain node.com"
            print_info "或下载后运行: sudo bash install.sh --solo --panel panel.com --node-domain node.com"
            exit 1
        fi
    fi
    
    panel_domain=$(echo "$panel_domain" | tr -d ' ')
    node_domain=$(echo "$node_domain" | tr -d ' ')
    
    if [ -z "$panel_domain" ] || [ -z "$node_domain" ]; then
        print_error "面板域名和节点域名都不能为空"
        exit 1
    fi
    
    print_info "管理面板域名: $panel_domain"
    print_info "节点域名: $node_domain"
    
    check_dns "$panel_domain" || {
        print_warning "面板域名 DNS 检查失败，但继续安装..."
    }
    check_dns "$node_domain" || {
        print_warning "节点域名 DNS 检查失败，但继续安装..."
    }
    
    print_warning "请确保两个域名都已正确解析到本服务器 IP"
    sleep 2
    
    if [ "$KEEP_CONFIG" = true ] && [ -f "/opt/xray-cluster/master/.env" ]; then
        print_info "读取现有密钥..."
        CLUSTER_SECRET=$(grep "^CLUSTER_SECRET=" /opt/xray-cluster/master/.env | cut -d'=' -f2)
        ADMIN_PASSWORD=$(grep "^ADMIN_PASSWORD=" /opt/xray-cluster/master/.env | cut -d'=' -f2)
        POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" /opt/xray-cluster/master/.env | cut -d'=' -f2)
        REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" /opt/xray-cluster/master/.env | cut -d'=' -f2)
        
        if [ -f "/opt/xray-cluster/node/.env" ]; then
            NODE_UUID=$(grep "^NODE_UUID=" /opt/xray-cluster/node/.env | cut -d'=' -f2)
            X25519_PRIVATE_KEY=$(grep "^X25519_PRIVATE_KEY=" /opt/xray-cluster/node/.env | cut -d'=' -f2)
            X25519_PUBLIC_KEY=$(grep "^X25519_PUBLIC_KEY=" /opt/xray-cluster/node/.env | cut -d'=' -f2)
            API_PATH=$(grep "^API_PATH=" /opt/xray-cluster/node/.env | cut -d'=' -f2)
            HYSTERIA_PASSWORD=$(grep "^HYSTERIA_PASSWORD=" /opt/xray-cluster/node/.env | cut -d'=' -f2)
        fi
        print_success "已读取现有配置"
    fi
    
    if [ -z "$CLUSTER_SECRET" ]; then
        CLUSTER_SECRET=$(generate_random_string 32)
    fi
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(generate_random_string 16)
    fi
    if [ -z "$POSTGRES_PASSWORD" ]; then
        POSTGRES_PASSWORD=$(generate_random_string 16)
    fi
    if [ -z "$REDIS_PASSWORD" ]; then
        REDIS_PASSWORD=$(generate_random_string 16)
    fi
    if [ -z "$HYSTERIA_PASSWORD" ]; then
        HYSTERIA_PASSWORD=$(generate_random_string 16)
    fi
    
    print_info "生成安全密钥..."
    echo ""
    
    if [ -z "$NODE_UUID" ]; then
        NODE_UUID=$(generate_uuid)
    fi
    if [ -z "$X25519_PRIVATE_KEY" ]; then
        X25519_KEYS=$(generate_x25519_keypair)
    fi
    
    if [ -z "$X25519_KEYS" ]; then
        print_warning "无法生成 x25519 密钥对，使用随机字符串代替"
        X25519_PRIVATE_KEY=$(generate_random_string 32)
        X25519_PUBLIC_KEY=$(generate_random_string 32)
    else
        X25519_PRIVATE_KEY=$(echo "$X25519_KEYS" | head -n1)
        X25519_PUBLIC_KEY=$(echo "$X25519_KEYS" | tail -n1)
    fi
    
    API_PATH=$(echo -n "${CLUSTER_SECRET}:$(date +%s):${NODE_UUID}" | sha256sum | cut -c1-16)
    HYSTERIA_PASSWORD=$(generate_random_string 16)
    
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
    mkdir -p /opt/xray-cluster/node/certs
    mkdir -p /opt/xray-cluster/node/logs
    
    print_info "准备应用文件..."
    if [ -d "master" ] && [ -f "master/app.py" ]; then
        print_info "检测到源代码，复制文件..."
        cp -r master/* /opt/xray-cluster/master/ 2>/dev/null || true
        cp -r node/* /opt/xray-cluster/node/ 2>/dev/null || true
        cp requirements.txt /opt/xray-cluster/master/ 2>/dev/null || true
        cp requirements.txt /opt/xray-cluster/node/ 2>/dev/null || true
    else
        print_warning "未检测到源代码目录，将使用 Git 克隆..."
        print_info "克隆项目代码..."
        cd /tmp
        git clone https://github.com/hioTEC/XUI-SOLO.git xui-solo-temp 2>/dev/null || {
            print_error "无法克隆代码仓库"
            print_info "请确保已安装 git 或手动下载项目代码"
            exit 1
        }
        cp -r xui-solo-temp/master/* /opt/xray-cluster/master/ 2>/dev/null || true
        cp -r xui-solo-temp/node/* /opt/xray-cluster/node/ 2>/dev/null || true
        cp xui-solo-temp/requirements.txt /opt/xray-cluster/master/ 2>/dev/null || true
        cp xui-solo-temp/requirements.txt /opt/xray-cluster/node/ 2>/dev/null || true
        rm -rf xui-solo-temp
        cd - > /dev/null
    fi
    
    if [ ! -f "/opt/xray-cluster/master/requirements.txt" ]; then
        print_info "创建 requirements.txt..."
        cat > /opt/xray-cluster/master/requirements.txt << 'EOFREQ'
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
EOFREQ
    fi
    
    if [ ! -f "/opt/xray-cluster/node/requirements.txt" ]; then
        cp /opt/xray-cluster/master/requirements.txt /opt/xray-cluster/node/requirements.txt
    fi
    
    if [ ! -f "/opt/xray-cluster/master/app.py" ]; then
        print_warning "app.py 不存在，创建最小版本..."
        cat > /opt/xray-cluster/master/app.py << 'EOFAPP'
from flask import Flask, render_template, jsonify
import os

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key')

@app.route('/')
def index():
    return jsonify({
        'status': 'ok',
        'message': 'XUI-SOLO Master Node',
        'version': '1.0.0'
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOFAPP
    fi
    
    if [ ! -f "/opt/xray-cluster/node/agent.py" ]; then
        print_warning "agent.py 不存在，创建最小版本..."
        cat > /opt/xray-cluster/node/agent.py << 'EOFAGENT'
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({
        'status': 'ok',
        'node_uuid': os.environ.get('NODE_UUID', 'unknown')
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOFAGENT
    fi
    
    cat > /opt/xray-cluster/master/.env << EOF
MASTER_DOMAIN=$panel_domain
PANEL_DOMAIN=$panel_domain
NODE_DOMAIN=$node_domain
CLUSTER_SECRET=$CLUSTER_SECRET
ADMIN_USER=admin
ADMIN_PASSWORD=$ADMIN_PASSWORD

# 数据库配置
POSTGRES_USER=xray_admin
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=xray_cluster

# Redis 配置
REDIS_PASSWORD=$REDIS_PASSWORD

# Caddy 配置 (内部端口 8080)
CADDY_EMAIL=admin@$panel_domain
EOF
    
    print_info "创建 Master 配置文件..."
    cat > /opt/xray-cluster/master/docker-compose.yml << 'EOFCOMPOSE'
version: '3.8'

services:
  caddy:
    image: caddy:2-alpine
    container_name: xray-master-caddy
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
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
      context: .
      dockerfile: Dockerfile.web
    container_name: xray-master-web
    restart: unless-stopped
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
      - xray-master-net

networks:
  xray-master-net:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  caddy_data:
  caddy_config:
EOFCOMPOSE

    # 创建 Master Caddyfile (SOLO模式 - 内部路由器，监听8080)
    cat > /opt/xray-cluster/master/Caddyfile << EOFCADDY
:8080 {
    
    @panel host ${panel_domain}
    handle @panel {
        encode gzip
        reverse_proxy web:5000 {
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto https
            header_up Host {host}
        }
    }
    
    @node host ${node_domain}
    handle @node {
        handle_path /${API_PATH}/* {
            reverse_proxy 127.0.0.1:8081
        }
        
        handle {
            respond "Welcome to our site" 200
        }
    }
    
    handle {
        encode gzip
        reverse_proxy web:5000 {
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto https
            header_up Host {host}
        }
    }
    
    log {
        output file /data/access.log {
            roll_size 10MiB
            roll_keep 5
        }
    }
}
EOFCADDY

    # 创建 Web Dockerfile (在 master 根目录)
    cat > /opt/xray-cluster/master/Dockerfile.web << 'EOFDOCKER'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY templates ./templates

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "app:app"]
EOFDOCKER
    
    cat > /opt/xray-cluster/node/.env << EOF
NODE_DOMAIN=$node_domain
PANEL_DOMAIN=$panel_domain
MASTER_DOMAIN=$panel_domain
CLUSTER_SECRET=$CLUSTER_SECRET
NODE_UUID=$NODE_UUID
X25519_PRIVATE_KEY=$X25519_PRIVATE_KEY
X25519_PUBLIC_KEY=$X25519_PUBLIC_KEY
API_PATH=$API_PATH

# Hysteria2 配置
HYSTERIA_PORT=50000
HYSTERIA_PASSWORD=$HYSTERIA_PASSWORD

# Caddy 配置 (内部端口 8080)
CADDY_EMAIL=admin@$node_domain
EOF
    
    print_info "创建 Worker 配置文件..."
    cat > /opt/xray-cluster/node/docker-compose.yml << 'EOFCOMPOSE'
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

    # 创建 Node Caddyfile
    cat > /opt/xray-cluster/node/Caddyfile << EOFCADDY
:80 {
    encode gzip
    
    handle_path /${API_PATH}/* {
        reverse_proxy agent:8080
    }
    
    respond "404 Not Found" 404
}
EOFCADDY

    # 创建 Xray 配置 (SOLO模式 - 网关模式，管理两个域名的证书和流量)
    cat > /opt/xray-cluster/node/xray_config/config.json << EOFXRAY
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${NODE_UUID}",
            "flow": "xtls-rprx-vision",
            "email": "user@${node_domain}"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": "127.0.0.1:8080",
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "${node_domain}",
          "certificates": [
            {
              "certificateFile": "/certs/${node_domain}.crt",
              "keyFile": "/certs/${node_domain}.key"
            },
            {
              "certificateFile": "/certs/${panel_domain}.crt",
              "keyFile": "/certs/${panel_domain}.key"
            }
          ],
          "alpn": ["h2", "http/1.1"],
          "minVersion": "1.2"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
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
        "ip": ["geoip:private"],
        "outboundTag": "block"
      }
    ]
  }
}
EOFXRAY

    # 创建ACME证书获取脚本
    cat > /opt/xray-cluster/node/get-certs.sh << EOFACME

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "\${BLUE}[INFO]\${NC} \$1"
}

print_success() {
    echo -e "\${GREEN}[SUCCESS]\${NC} \$1"
}

print_error() {
    echo -e "\${RED}[ERROR]\${NC} \$1"
}

print_warning() {
    echo -e "\${YELLOW}[WARNING]\${NC} \$1"
}

# 从 .env 文件读取域名
if [ -f /opt/xray-cluster/node/.env ]; then
    source /opt/xray-cluster/node/.env
    PANEL_DOMAIN=\${PANEL_DOMAIN:-${panel_domain}}
    NODE_DOMAIN=\${NODE_DOMAIN:-${node_domain}}
else
    PANEL_DOMAIN="${panel_domain}"
    NODE_DOMAIN="${node_domain}"
fi

CERT_DIR="/opt/xray-cluster/node/certs"

print_info "准备获取 SSL 证书..."
print_info "面板域名: \$PANEL_DOMAIN"
print_info "节点域名: \$NODE_DOMAIN"

# 检查依赖
print_info "检查依赖..."

# 检查 curl
if ! command -v curl &> /dev/null; then
    print_warning "curl 未安装，正在安装..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y curl
    elif command -v yum &> /dev/null; then
        yum install -y curl
    else
        print_error "无法自动安装 curl，请手动安装"
        exit 1
    fi
fi

# 检查 socat（acme.sh standalone 模式需要）
if ! command -v socat &> /dev/null; then
    print_warning "socat 未安装，正在安装..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y socat
    elif command -v yum &> /dev/null; then
        yum install -y socat
    else
        print_error "无法自动安装 socat，请手动安装"
        exit 1
    fi
fi

# 检查 cron（用于自动续期）
if ! command -v crontab &> /dev/null; then
    print_warning "cron 未安装，正在安装..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y cron
        systemctl enable cron
        systemctl start cron
    elif command -v yum &> /dev/null; then
        yum install -y cronie
        systemctl enable crond
        systemctl start crond
    else
        print_warning "无法自动安装 cron，证书将无法自动续期"
    fi
fi

print_success "依赖检查完成"

# 安装 acme.sh
if [ ! -d ~/.acme.sh ]; then
    print_info "安装 acme.sh..."
    curl -s https://get.acme.sh | sh -s email=admin@\$PANEL_DOMAIN
    
    if [ -f ~/.bashrc ]; then
        source ~/.bashrc
    fi
    
    print_success "acme.sh 安装完成"
else
    print_info "acme.sh 已安装"
fi

# 设置 acme.sh 路径
ACME_SH="\$HOME/.acme.sh/acme.sh"

if [ ! -f "\$ACME_SH" ]; then
    print_error "acme.sh 未找到，请检查安装"
    exit 1
fi

# 检查端口 80 是否被占用
if netstat -tlnp 2>/dev/null | grep -q ':80 ' || ss -tlnp 2>/dev/null | grep -q ':80 '; then
    print_error "端口 80 已被占用，请先停止占用端口的服务"
    print_info "提示：运行 'cd /opt/xray-cluster/node && docker-compose stop xray' 停止 Xray"
    exit 1
fi

# 获取面板域名证书
print_info "获取面板域名证书: \$PANEL_DOMAIN"
if "\$ACME_SH" --issue -d "\$PANEL_DOMAIN" --standalone --httpport 80 --force; then
    print_success "面板域名证书获取成功"
else
    print_error "面板域名证书获取失败"
    print_info "请检查："
    print_info "  1. 域名 \$PANEL_DOMAIN 是否已解析到本服务器"
    print_info "  2. 端口 80 是否可从公网访问"
    print_info "  3. 防火墙是否已开放端口 80"
    exit 1
fi

# 获取节点域名证书
print_info "获取节点域名证书: \$NODE_DOMAIN"
if "\$ACME_SH" --issue -d "\$NODE_DOMAIN" --standalone --httpport 80 --force; then
    print_success "节点域名证书获取成功"
else
    print_error "节点域名证书获取失败"
    print_info "请检查："
    print_info "  1. 域名 \$NODE_DOMAIN 是否已解析到本服务器"
    print_info "  2. 端口 80 是否可从公网访问"
    print_info "  3. 防火墙是否已开放端口 80"
    exit 1
fi

# 创建证书目录
mkdir -p "\$CERT_DIR"

# 安装面板域名证书
print_info "安装面板域名证书..."
"\$ACME_SH" --install-cert -d "\$PANEL_DOMAIN" \\
    --key-file "\$CERT_DIR/\$PANEL_DOMAIN.key" \\
    --fullchain-file "\$CERT_DIR/\$PANEL_DOMAIN.crt" \\
    --reloadcmd "cd /opt/xray-cluster/node && docker-compose restart xray"

# 安装节点域名证书
print_info "安装节点域名证书..."
"\$ACME_SH" --install-cert -d "\$NODE_DOMAIN" \\
    --key-file "\$CERT_DIR/\$NODE_DOMAIN.key" \\
    --fullchain-file "\$CERT_DIR/\$NODE_DOMAIN.crt" \\
    --reloadcmd "cd /opt/xray-cluster/node && docker-compose restart xray"

# 设置权限
chmod 600 "\$CERT_DIR"/*.key
chmod 644 "\$CERT_DIR"/*.crt

print_success "证书安装完成！"
print_info "证书位置: \$CERT_DIR"
print_info "证书将在 60 天后自动续期"

# 验证证书
print_info "验证证书..."
ls -lh "\$CERT_DIR"

# 重启 Xray
print_info "重启 Xray 服务..."
cd /opt/xray-cluster/node && docker-compose restart xray

print_success "所有操作完成！"
print_info "现在可以访问 https://\$PANEL_DOMAIN"
EOFACME

    chmod +x /opt/xray-cluster/node/get-certs.sh
    
    print_info "生成自签名 SSL 证书..."
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /opt/xray-cluster/node/certs/${panel_domain}.key \
        -out /opt/xray-cluster/node/certs/${panel_domain}.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${panel_domain}" \
        2>/dev/null
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /opt/xray-cluster/node/certs/${node_domain}.key \
        -out /opt/xray-cluster/node/certs/${node_domain}.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${node_domain}" \
        2>/dev/null
    
    chmod 600 /opt/xray-cluster/node/certs/*.key
    chmod 644 /opt/xray-cluster/node/certs/*.crt
    
    print_success "自签名证书已生成（浏览器会显示警告，可忽略或稍后使用 acme.sh 获取正式证书）"

    # 创建 Agent Dockerfile (在 node 根目录)
    cat > /opt/xray-cluster/node/Dockerfile.agent << 'EOFDOCKER'
FROM python:3.11-slim

WORKDIR /app

COPY agent.py .
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8080

CMD ["python", "agent.py"]
EOFDOCKER
    
    if [ "$KEEP_CONFIG" = true ]; then
        print_info "停止现有服务..."
        cd /opt/xray-cluster/master && docker-compose down 2>/dev/null || true
        cd /opt/xray-cluster/node && docker-compose down 2>/dev/null || true
    fi
    
    print_info "启动 Master 控制面板..."
    cd /opt/xray-cluster/master
    docker-compose up -d --build
    
    print_info "等待 Master 服务启动..."
    sleep 10
    
    print_info "启动本地 Worker 节点..."
    cd /opt/xray-cluster/node
    
    docker-compose down --remove-orphans 2>/dev/null || true
    
    docker-compose up -d --build
    
    print_info "等待服务完全启动..."
    sleep 5
    
    echo ""
    echo "========================================"
    print_success "SOLO 模式安装完成！"
    echo "========================================"
    echo ""
    print_info "访问信息:"
    echo "  控制面板: https://${panel_domain}"
    echo "  节点域名: https://${node_domain}"
    echo "  管理员账号: admin"
    echo "  管理员密码: ${ADMIN_PASSWORD}"
    echo ""
    print_info "集群信息:"
    echo "  集群密钥: ${CLUSTER_SECRET}"
    echo "  节点UUID: ${NODE_UUID}"
    echo ""
    print_info "架构说明 (One Port Rule):"
    echo "  - Xray 监听 443 端口（网关）"
    echo "  - 管理面板流量: ${panel_domain}:443 -> Xray -> Caddy -> Web"
    echo "  - 代理流量: ${node_domain}:443 -> Xray -> 代理"
    echo "  - 伪装网站: ${node_domain}:443 (浏览器) -> Xray -> Caddy -> 静态页面"
    echo ""
    print_warning "重要提示:"
    echo "  1. 请妥善保存上述信息"
    echo "  2. 首次登录后请立即修改管理员密码"
    echo "  3. 确保防火墙已开放以下端口:"
    echo "     - 80/TCP (HTTP, 用于证书验证)"
    echo "     - 443/TCP (HTTPS, Xray网关)"
    echo "     - 50000/UDP (Hysteria2, 可选)"
    echo ""
    print_info "SSL 证书说明:"
    echo "  - 当前使用自签名证书（浏览器会显示安全警告）"
    echo "  - 访问 https://${panel_domain} 时，点击「高级」->「继续访问」即可"
    echo "  - 获取正式证书（推荐）:"
    echo "    cd /opt/xray-cluster/node && bash get-certs.sh"
    echo ""
    print_info "添加更多 Worker 节点时使用集群密钥"
    echo ""
    
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
    
    MODE=""
    PANEL_DOMAIN=""
    NODE_DOMAIN=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --solo)
                MODE="solo"
                shift
                ;;
            --master)
                MODE="master"
                shift
                ;;
            --node)
                MODE="node"
                shift
                ;;
            --uninstall)
                MODE="uninstall"
                shift
                ;;
            --panel)
                PANEL_DOMAIN="$2"
                shift 2
                ;;
            --node-domain)
                NODE_DOMAIN="$2"
                shift 2
                ;;
            --domain)
                PANEL_DOMAIN="$2"
                NODE_DOMAIN="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [ "$MODE" = "solo" ]; then
        check_docker
        install_solo "$PANEL_DOMAIN" "$NODE_DOMAIN"
    elif [ "$MODE" = "master" ]; then
        check_docker
        install_master
    elif [ "$MODE" = "node" ]; then
        check_docker
        install_node
    elif [ "$MODE" = "uninstall" ]; then
        uninstall_service
    else
        main_menu
    fi
}

# 运行主函数
main "$@"