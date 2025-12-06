#!/bin/bash
# 使用 acme.sh 获取 SSL 证书
# 用法: bash get-certs.sh [面板域名] [节点域名]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 从参数或 .env 文件读取域名
if [ -n "$1" ] && [ -n "$2" ]; then
    PANEL_DOMAIN="$1"
    NODE_DOMAIN="$2"
elif [ -f /opt/xray-cluster/node/.env ]; then
    source /opt/xray-cluster/node/.env
    PANEL_DOMAIN=${PANEL_DOMAIN}
    NODE_DOMAIN=${NODE_DOMAIN}
else
    print_error "无法获取域名信息"
    print_info "用法: bash get-certs.sh [面板域名] [节点域名]"
    print_info "或确保 /opt/xray-cluster/node/.env 文件存在"
    exit 1
fi

if [ -z "$PANEL_DOMAIN" ] || [ -z "$NODE_DOMAIN" ]; then
    print_error "域名不能为空"
    exit 1
fi

CERT_DIR="/opt/xray-cluster/node/certs"

print_info "准备获取 SSL 证书..."
print_info "面板域名: $PANEL_DOMAIN"
print_info "节点域名: $NODE_DOMAIN"
echo ""

# 检查是否为 root
if [ "$(id -u)" != "0" ]; then
    print_error "请使用 root 或 sudo 运行此脚本"
    exit 1
fi

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
        systemctl enable cron 2>/dev/null || true
        systemctl start cron 2>/dev/null || true
    elif command -v yum &> /dev/null; then
        yum install -y cronie
        systemctl enable crond 2>/dev/null || true
        systemctl start crond 2>/dev/null || true
    else
        print_warning "无法自动安装 cron，证书将无法自动续期"
    fi
fi

# 检查 netstat 或 ss
if ! command -v netstat &> /dev/null && ! command -v ss &> /dev/null; then
    print_warning "netstat/ss 未安装，正在安装..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y net-tools
    elif command -v yum &> /dev/null; then
        yum install -y net-tools
    fi
fi

print_success "依赖检查完成"
echo ""

# 安装 acme.sh
if [ ! -d ~/.acme.sh ]; then
    print_info "安装 acme.sh..."
    curl -s https://get.acme.sh | sh -s email=admin@$PANEL_DOMAIN
    
    # 重新加载环境变量
    if [ -f ~/.bashrc ]; then
        source ~/.bashrc
    fi
    
    print_success "acme.sh 安装完成"
else
    print_info "acme.sh 已安装"
fi

# 设置 acme.sh 路径
ACME_SH="$HOME/.acme.sh/acme.sh"

if [ ! -f "$ACME_SH" ]; then
    print_error "acme.sh 未找到，请检查安装"
    exit 1
fi

echo ""

# 检查端口 80 是否被占用
print_info "检查端口 80..."
if netstat -tlnp 2>/dev/null | grep -q ':80 ' || ss -tlnp 2>/dev/null | grep -q ':80 '; then
    print_error "端口 80 已被占用"
    print_info "请先停止占用端口的服务："
    print_info "  cd /opt/xray-cluster/node && docker-compose stop xray"
    echo ""
    read -p "是否自动停止 Xray 服务？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "停止 Xray 服务..."
        cd /opt/xray-cluster/node && docker-compose stop xray
        sleep 2
    else
        exit 1
    fi
fi

print_success "端口 80 可用"
echo ""

# 获取面板域名证书
print_info "获取面板域名证书: $PANEL_DOMAIN"
if "$ACME_SH" --issue -d "$PANEL_DOMAIN" --standalone --httpport 80 --force; then
    print_success "面板域名证书获取成功"
else
    print_error "面板域名证书获取失败"
    echo ""
    print_info "请检查："
    print_info "  1. 域名 $PANEL_DOMAIN 是否已解析到本服务器"
    print_info "  2. 端口 80 是否可从公网访问"
    print_info "  3. 防火墙是否已开放端口 80"
    echo ""
    print_info "验证 DNS 解析："
    print_info "  dig $PANEL_DOMAIN"
    print_info "  nslookup $PANEL_DOMAIN"
    exit 1
fi

echo ""

# 获取节点域名证书
print_info "获取节点域名证书: $NODE_DOMAIN"
if "$ACME_SH" --issue -d "$NODE_DOMAIN" --standalone --httpport 80 --force; then
    print_success "节点域名证书获取成功"
else
    print_error "节点域名证书获取失败"
    echo ""
    print_info "请检查："
    print_info "  1. 域名 $NODE_DOMAIN 是否已解析到本服务器"
    print_info "  2. 端口 80 是否可从公网访问"
    print_info "  3. 防火墙是否已开放端口 80"
    echo ""
    print_info "验证 DNS 解析："
    print_info "  dig $NODE_DOMAIN"
    print_info "  nslookup $NODE_DOMAIN"
    exit 1
fi

echo ""

# 创建证书目录
mkdir -p "$CERT_DIR"

# 安装面板域名证书
print_info "安装面板域名证书..."
"$ACME_SH" --install-cert -d "$PANEL_DOMAIN" \
    --key-file "$CERT_DIR/$PANEL_DOMAIN.key" \
    --fullchain-file "$CERT_DIR/$PANEL_DOMAIN.crt" \
    --reloadcmd "cd /opt/xray-cluster/node && docker-compose restart xray"

# 安装节点域名证书
print_info "安装节点域名证书..."
"$ACME_SH" --install-cert -d "$NODE_DOMAIN" \
    --key-file "$CERT_DIR/$NODE_DOMAIN.key" \
    --fullchain-file "$CERT_DIR/$NODE_DOMAIN.crt" \
    --reloadcmd "cd /opt/xray-cluster/node && docker-compose restart xray"

# 设置权限
chmod 600 "$CERT_DIR"/*.key
chmod 644 "$CERT_DIR"/*.crt

echo ""
print_success "证书安装完成！"
print_info "证书位置: $CERT_DIR"
print_info "证书将在 60 天后自动续期"

# 验证证书
echo ""
print_info "证书文件："
ls -lh "$CERT_DIR"

# 重启 Xray
echo ""
print_info "重启 Xray 服务..."
cd /opt/xray-cluster/node && docker-compose start xray

sleep 3

echo ""
print_success "所有操作完成！"
print_info "现在可以访问 https://$PANEL_DOMAIN"
print_info "浏览器将不再显示安全警告"
echo ""
print_info "查看 Xray 状态："
print_info "  cd /opt/xray-cluster/node && docker-compose ps"
echo ""
print_info "查看 Xray 日志："
print_info "  cd /opt/xray-cluster/node && docker-compose logs xray"
