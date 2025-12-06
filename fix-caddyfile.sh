#!/bin/bash

# 快速修复 Caddyfile 路由问题

set -e

echo "=== 修复 Caddyfile 路由配置 ==="
echo ""

# 读取域名配置
if [ -f /opt/xray-cluster/master/.env ]; then
    source /opt/xray-cluster/master/.env
else
    echo "错误：找不到配置文件"
    exit 1
fi

if [ -f /opt/xray-cluster/node/.env ]; then
    source /opt/xray-cluster/node/.env
fi

echo "面板域名: $PANEL_DOMAIN"
echo "节点域名: $NODE_DOMAIN"
echo ""

# 备份原配置
if [ -f /opt/xray-cluster/master/Caddyfile ]; then
    cp /opt/xray-cluster/master/Caddyfile /opt/xray-cluster/master/Caddyfile.backup
    echo "✓ 已备份原配置到 Caddyfile.backup"
fi

# 创建新的 Caddyfile
cat > /opt/xray-cluster/master/Caddyfile << EOFCADDY
# 监听内部端口 8080，由 Xray fallback 转发过来
:8080 {
    # 根据 Host 头路由
    
    # 管理面板域名 -> Web 应用
    @panel host ${PANEL_DOMAIN}
    handle @panel {
        encode gzip
        reverse_proxy web:5000 {
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto https
            header_up Host {host}
        }
    }
    
    # 节点域名 -> 伪装网站 + Agent API
    @node host ${NODE_DOMAIN}
    handle @node {
        # Agent API 路径
        handle_path /${API_PATH}/* {
            reverse_proxy 127.0.0.1:8081
        }
        
        # 伪装网站
        handle {
            respond "Welcome to our site" 200
        }
    }
    
    # 默认：所有其他请求也转发到 Web 应用（兼容性更好）
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

echo "✓ 已更新 Caddyfile"
echo ""

# 重启 Caddy
echo "重启 Caddy 服务..."
cd /opt/xray-cluster/master
docker-compose restart caddy

echo ""
echo "✓ 修复完成！"
echo ""
echo "请等待 5 秒后访问："
echo "  https://${PANEL_DOMAIN}"
echo ""
echo "如果仍有问题，请检查："
echo "  1. 域名 DNS 是否正确解析"
echo "  2. SSL 证书是否已获取"
echo "  3. 运行: cd /opt/xray-cluster/master && docker-compose logs caddy"
