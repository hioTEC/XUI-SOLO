#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

[ "$(id -u)" != "0" ] && print_error "需要 root 权限" && exit 1

if [ ! -f /opt/xray-cluster/node/.env ]; then
    print_error "未找到安装，请先运行 install.sh"
    exit 1
fi

source /opt/xray-cluster/node/.env

print_info "修复 Xray 配置..."

cat > /opt/xray-cluster/node/xray_config/config.json << EOF
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
            "flow": "xtls-rprx-vision"
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
          "certificates": [
            {
              "certificateFile": "/certs/${NODE_DOMAIN}.crt",
              "keyFile": "/certs/${NODE_DOMAIN}.key"
            },
            {
              "certificateFile": "/certs/${PANEL_DOMAIN}.crt",
              "keyFile": "/certs/${PANEL_DOMAIN}.key"
            }
          ],
          "alpn": ["h2", "http/1.1"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

print_success "配置已更新"

print_info "停止服务..."
cd /opt/xray-cluster/node
docker-compose stop xray
sleep 2

print_info "获取 SSL 证书..."

if [ ! -d ~/.acme.sh ]; then
    print_info "安装 acme.sh..."
    curl -s https://get.acme.sh | sh -s email=admin@${PANEL_DOMAIN}
    source ~/.bashrc
fi

ACME_SH="$HOME/.acme.sh/acme.sh"

"$ACME_SH" --set-default-ca --server letsencrypt

for domain in "$PANEL_DOMAIN" "$NODE_DOMAIN"; do
    print_info "获取证书: $domain"
    if "$ACME_SH" --issue -d "$domain" --standalone --httpport 80 --server letsencrypt --force; then
        "$ACME_SH" --install-cert -d "$domain" \
            --key-file "/opt/xray-cluster/node/certs/$domain.key" \
            --fullchain-file "/opt/xray-cluster/node/certs/$domain.crt"
        print_success "证书获取成功: $domain"
    else
        print_error "证书获取失败: $domain"
        print_info "使用自签名证书..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "/opt/xray-cluster/node/certs/$domain.key" \
            -out "/opt/xray-cluster/node/certs/$domain.crt" \
            -subj "/CN=$domain" 2>/dev/null
    fi
done

chmod 600 /opt/xray-cluster/node/certs/*.key
chmod 644 /opt/xray-cluster/node/certs/*.crt

print_info "启动服务..."
cd /opt/xray-cluster/node
docker-compose start xray

cd /opt/xray-cluster/master
docker-compose restart

sleep 5

print_success "修复完成！"
print_info "访问: https://${PANEL_DOMAIN}"
print_info "如使用自签名证书，浏览器会显示警告，点击「高级」->「继续访问」"
