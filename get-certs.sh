#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

if [ -n "$1" ] && [ -n "$2" ]; then
    PANEL_DOMAIN="$1"
    NODE_DOMAIN="$2"
elif [ -f /opt/xray-cluster/node/.env ]; then
    source /opt/xray-cluster/node/.env
else
    print_error "用法: bash get-certs.sh [面板域名] [节点域名]"
    exit 1
fi

[ -z "$PANEL_DOMAIN" ] || [ -z "$NODE_DOMAIN" ] && print_error "域名不能为空" && exit 1
[ "$(id -u)" != "0" ] && print_error "需要 root 权限" && exit 1

CERT_DIR="/opt/xray-cluster/node/certs"

print_info "面板: $PANEL_DOMAIN | 节点: $NODE_DOMAIN"

install_pkg() {
    if command -v apt-get &> /dev/null; then
        apt-get update -qq && apt-get install -y -qq $1
    elif command -v yum &> /dev/null; then
        yum install -y -q $1
    else
        print_error "无法安装 $1"
        exit 1
    fi
}

for tool in curl socat cron; do
    if ! command -v $tool &> /dev/null; then
        print_warning "安装 $tool..."
        [ "$tool" = "cron" ] && tool="cron cronie" || true
        install_pkg "$tool"
    fi
done

if [ ! -d ~/.acme.sh ]; then
    print_info "安装 acme.sh..."
    curl -s https://get.acme.sh | sh -s email=admin@$PANEL_DOMAIN
    [ -f ~/.bashrc ] && source ~/.bashrc
fi

ACME_SH="$HOME/.acme.sh/acme.sh"
[ ! -f "$ACME_SH" ] && print_error "acme.sh 未找到" && exit 1

if netstat -tlnp 2>/dev/null | grep -q ':80 ' || ss -tlnp 2>/dev/null | grep -q ':80 '; then
    print_warning "端口 80 被占用"
    read -p "停止 Xray? (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && cd /opt/xray-cluster/node && docker-compose stop xray && sleep 2 || exit 1
fi

for domain in "$PANEL_DOMAIN" "$NODE_DOMAIN"; do
    print_info "获取证书: $domain"
    if ! "$ACME_SH" --issue -d "$domain" --standalone --httpport 80 --force 2>/dev/null; then
        print_error "失败: $domain"
        print_info "检查: 1) DNS解析 2) 端口80可访问 3) 防火墙"
        exit 1
    fi
done

mkdir -p "$CERT_DIR"

for domain in "$PANEL_DOMAIN" "$NODE_DOMAIN"; do
    "$ACME_SH" --install-cert -d "$domain" \
        --key-file "$CERT_DIR/$domain.key" \
        --fullchain-file "$CERT_DIR/$domain.crt" \
        --reloadcmd "cd /opt/xray-cluster/node && docker-compose restart xray" 2>/dev/null
done

chmod 600 "$CERT_DIR"/*.key
chmod 644 "$CERT_DIR"/*.crt

print_success "证书已安装: $CERT_DIR"
cd /opt/xray-cluster/node && docker-compose start xray
sleep 3
print_success "完成! 访问 https://$PANEL_DOMAIN"
