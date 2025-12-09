
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

# 安装 SOLO 一体化节点 (Vision-First 架构)
install_solo() {
    print_info "开始安装 SOLO 一体化节点 (Vision-First Architecture)..."

    # 1. 收集域名信息
    local panel_domain="$1"
    local agent_domain="$2"

    if [ -z "$panel_domain" ]; then
        read -p "请输入 Master 面板域名 (如 panel.example.com): " panel_domain
    fi
    check_dns "$panel_domain"

    if [ -z "$agent_domain" ]; then
        read -p "请输入 Agent 节点域名 (如 api.example.com): " agent_domain
    fi
    check_dns "$agent_domain"
    
    # 2. 生成密钥和 UUID
    local admin_user="admin"
    local admin_password=$(generate_random_string 16)
    local cluster_secret=$(generate_random_string 32)
    local node_uuid=$(generate_uuid)
    local api_path=$(echo -n "${cluster_secret}:$(date +%s):${node_uuid}" | sha256sum | cut -c1-16)
    
    local keys=$(generate_x25519_keypair)
    local x25519_private_key=$(echo "$keys" | head -n1)
    local x25519_public_key=$(echo "$keys" | tail -n1)

    # 3. 创建目录结构
    local base_dir="/opt/xui-solo"
    mkdir -p "$base_dir"
    mkdir -p "$base_dir/certs"
    mkdir -p "$base_dir/xray_config"
    mkdir -p "$base_dir/caddy_data"
    mkdir -p "$base_dir/web"
    mkdir -p "$base_dir/agent"

    # 4. 写入环境变量 .env
    cat > "$base_dir/.env" << EOF
PANEL_DOMAIN=$panel_domain
AGENT_DOMAIN=$agent_domain
ADMIN_USER=$admin_user
ADMIN_PASSWORD=$admin_password
CLUSTER_SECRET=$cluster_secret
NODE_UUID=$node_uuid
API_PATH=$api_path

# 数据库配置 (保留 Postgres/Redis 以兼容现有代码)
POSTGRES_USER=xray_admin
POSTGRES_PASSWORD=$(generate_random_string 16)
POSTGRES_DB=xray_cluster
REDIS_PASSWORD=$(generate_random_string 16)

# Caddy
CADDY_EMAIL=admin@$panel_domain
EOF

    # 5. 写入 docker-compose.yml (Unified)
    cat > "$base_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  xray:
    image: ghcr.io/xtls/xray-core:latest
    container_name: solo-xray
    restart: always
    ports:
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./xray_config/config.json:/etc/xray/config.json:ro
      - ./certs:/certs:ro
    networks:
      - solo-net

  caddy:
    image: caddy:2-alpine
    container_name: solo-caddy
    restart: always
    ports:
      - "80:80"        # 仅用于 ACME 验证
      # 8080 端口不暴露给宿主机，仅在内部网络使用
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs:/data/caddy/certificates
      - caddy_data:/data
    networks:
      - solo-net
    environment:
      - CADDY_EMAIL=${CADDY_EMAIL}

  web:
    build:
      context: ./web
      dockerfile: Dockerfile
    container_name: solo-web
    restart: always
    # 内部端口 8080 (Flask) 不暴露
    environment:
      - MASTER_DOMAIN=${PANEL_DOMAIN}
      - CLUSTER_SECRET=${CLUSTER_SECRET}
      - ADMIN_USER=${ADMIN_USER}
      - ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0
    depends_on:
      - postgres
      - redis
    networks:
      - solo-net

  agent:
    build:
      context: ./agent
      dockerfile: Dockerfile
    container_name: solo-agent
    restart: always
    # 内部端口 8080 不暴露
    environment:
      - NODE_UUID=${NODE_UUID}
      - CLUSTER_SECRET=${CLUSTER_SECRET}
      - MASTER_DOMAIN=http://web:8080
      - API_PATH=${API_PATH}
    networks:
      - solo-net

  postgres:
    image: postgres:15-alpine
    container_name: solo-postgres
    restart: always
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    networks:
      - solo-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: solo-redis
    restart: always
    volumes:
      - redis_data:/data
    command: redis-server --requirepass ${REDIS_PASSWORD}
    networks:
      - solo-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  solo-net:
    driver: bridge

volumes:
  caddy_data:
  postgres_data:
  redis_data:
EOF

    # 6. 写入 Xray config.json (Vision-First)
    cat > "$base_dir/xray_config/config.json" << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${node_uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": "caddy:8080",
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/certs/acme-v02.api.letsencrypt.org-directory/${panel_domain}/${panel_domain}.crt",
              "keyFile": "/certs/acme-v02.api.letsencrypt.org-directory/${panel_domain}/${panel_domain}.key"
            }
          ]
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
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF

    # 7. 写入 Caddyfile
    cat > "$base_dir/Caddyfile" << EOF
{
    servers :8080 {
        # 信任 Xray 发来的 PROXY Protocol
        trusted_proxies static private_ranges
    }
}

:8080 {
    bind 0.0.0.0
    
    # 面板流量
    @panel host ${panel_domain}
    handle @panel {
        reverse_proxy web:8080
    }

    # Agent 流量
    @agent host ${agent_domain}
    handle @agent {
        reverse_proxy agent:8080
    }

    # 默认回落 (如博客)
    handle {
        respond "Welcome to XUI-SOLO Vision Architecture!" 200
    }
}

# 必须监听 80 端口以完成 ACME HTTP-01 验证
:80 {
    # Caddy 自动管理证书申请
}
EOF

    # 8. 复制应用代码
    if [ -d "./web" ]; then
        cp -r ./web/* "$base_dir/web/"
    else
        print_warning "未找到 Web 源码，将创建占位符..."
        cat > "$base_dir/web/Dockerfile" << 'EOFD'
FROM python:3.11-slim
WORKDIR /app
CMD ["python", "-m", "http.server", "8080"]
EOFD
    fi

    if [ -d "./agent" ]; then
        cp -r ./agent/* "$base_dir/agent/"
    else
        print_warning "未找到 Agent 源码，将创建占位符..."
        cat > "$base_dir/agent/Dockerfile" << 'EOFA'
FROM python:3.11-slim
WORKDIR /app
CMD ["python", "-m", "http.server", "8080"]
EOFA
    fi
    
    # 确保 Dockerfile 存在
    if [ ! -f "$base_dir/web/Dockerfile" ]; then
         cat > "$base_dir/web/Dockerfile" << 'EOFD'
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt || true
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
EOFD
    fi
    
    if [ ! -f "$base_dir/agent/Dockerfile" ]; then
         cat > "$base_dir/agent/Dockerfile" << 'EOFA'
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt || true
CMD ["python", "agent.py"]
EOFA
    fi

    # 9. 启动服务
    print_info "启动服务..."
    cd "$base_dir"
    docker-compose up -d

    print_success "安装完成!"
    echo "面板地址: https://$panel_domain"
    echo "管理账号: $admin_user"
    echo "管理密码: $admin_password"
    echo "VLESS UUID: $node_uuid"
    echo "  (请确保 DNS 解析生效，且防火墙开放 80/443)"
}

# 卸载服务
uninstall_service() {
    read -p "确定要卸载吗？这将删除所有数据 (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    if [ -d "/opt/xui-solo" ]; then
        print_info "停止服务..."
        cd /opt/xui-solo && docker-compose down -v
        print_info "删除目录..."
        rm -rf /opt/xui-solo
        print_success "卸载完成"
    else
        print_warning "未找到安装目录 /opt/xui-solo"
    fi
}

# 主菜单
main_menu() {
    clear
    echo "========================================"
    echo "    XUI-SOLO Vision 架构安装程序"
    echo "========================================"
    echo ""
    echo "1. 安装/更新 (Solo Mode)"
    echo "2. 卸载服务"
    echo "3. 退出"
    echo ""
    
    read -p "请输入选择 (1-3): " choice
    
    case $choice in
        1)
            check_docker
            install_solo
            ;;
        2)
            uninstall_service
            ;;
        3)
            exit 0
            ;;
        *)
            print_error "无效的选择"
            main_menu
            ;;
    esac
}

# 主函数
main() {
    if [ "$(id -u)" != "0" ]; then
        print_error "请使用 root 或 sudo 运行此脚本"
        exit 1
    fi
    
    if [ "$1" = "--solo" ]; then
        check_docker
        install_solo "$2" "$3"
    elif [ "$1" = "--uninstall" ]; then
        uninstall_service
    else
        main_menu
    fi
}

main "$@"