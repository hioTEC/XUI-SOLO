# Xray集群管理系统 - 部署指南

## 快速开始

### 系统要求

- **操作系统**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **内存**: 最低 2GB (Master), 1GB (Node)
- **磁盘**: 最低 20GB
- **域名**: 需要有效的域名和SSL证书

### 一键安装

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/your-repo/xray-cluster/main/install.sh
chmod +x install.sh

# 安装Master节点
sudo ./install.sh --master

# 安装Worker节点
sudo ./install.sh --node
```

## 详细部署步骤

### 1. 部署Master节点（控制面板）

#### 1.1 准备工作

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com | sh
sudo systemctl enable docker
sudo systemctl start docker

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### 1.2 配置域名

确保你的域名已经解析到服务器IP：

```bash
# 检查DNS解析
dig panel.example.com +short
# 应该返回你的服务器IP
```

#### 1.3 运行安装脚本

```bash
sudo ./install.sh --master
```

安装过程中会提示输入：
- Master面板域名（如：panel.example.com）
- 自动生成集群密钥（请妥善保存！）

#### 1.4 访问控制面板

安装完成后，访问 `https://panel.example.com`

默认登录信息会在安装完成后显示：
```
管理员账号: admin
管理员密码: [自动生成的密码]
```

### 2. 部署Worker节点（代理节点）

#### 2.1 准备工作

在新的服务器上重复Master节点的准备工作（安装Docker等）

#### 2.2 配置域名

确保节点域名已解析：

```bash
dig node1.example.com +short
```

#### 2.3 运行安装脚本

```bash
sudo ./install.sh --node
```

安装过程中会提示输入：
- 集群密钥（从Master安装时获得）
- Master面板域名
- 本节点域名

#### 2.4 验证节点状态

1. 登录Master控制面板
2. 进入"节点管理"页面
3. 查看新节点是否显示为"在线"状态

### 3. 配置节点

#### 3.1 在Master面板添加节点

1. 登录控制面板
2. 点击"添加节点"
3. 填写节点信息：
   - 节点名称
   - 服务器IP
   - 位置
   - 描述
   - 协议配置（VLESS、SplitHTTP、Hysteria2）
   - 最大用户数

4. 保存后会生成节点Token

#### 3.2 配置节点连接

节点会自动使用Token向Master注册，无需手动配置。

## 配置说明

### Master环境变量

编辑 `/opt/xray-cluster/master/.env`：

```bash
# Master配置
MASTER_DOMAIN=panel.example.com
CLUSTER_SECRET=your-cluster-secret
ADMIN_USER=admin
ADMIN_PASSWORD=your-secure-password

# 数据库配置
POSTGRES_USER=xray_admin
POSTGRES_PASSWORD=your-db-password
POSTGRES_DB=xray_cluster

# Redis配置
REDIS_PASSWORD=your-redis-password
```

### Node环境变量

编辑 `/opt/xray-cluster/node/.env`：

```bash
# Node配置
NODE_DOMAIN=node1.example.com
MASTER_DOMAIN=panel.example.com
CLUSTER_SECRET=your-cluster-secret
NODE_UUID=auto-generated-uuid
API_PATH=auto-generated-path

# Hysteria2配置
HYSTERIA_PORT=50000
HYSTERIA_PASSWORD=auto-generated
```

## 管理命令

### Master节点

```bash
# 查看服务状态
cd /opt/xray-cluster/master
docker-compose ps

# 查看日志
docker-compose logs -f web

# 重启服务
docker-compose restart

# 停止服务
docker-compose down

# 备份数据库
docker-compose exec postgres pg_dump -U xray_admin xray_cluster > backup.sql
```

### Worker节点

```bash
# 查看服务状态
cd /opt/xray-cluster/node
docker-compose ps

# 查看Xray日志
docker-compose logs -f xray

# 查看Agent日志
docker-compose logs -f agent

# 重启Xray
docker-compose restart xray

# 重启Agent
docker-compose restart agent

# 完全重启
docker-compose restart
```

## 安全建议

### 1. 防火墙配置

**Master节点**:
```bash
# 只开放必要端口
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (重定向到HTTPS)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

**Worker节点**:
```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 443/tcp   # VLESS
sudo ufw allow 443/udp   # VLESS UDP
sudo ufw allow 50000/udp # Hysteria2
sudo ufw enable
```

### 2. 定期更新

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 更新Docker镜像
cd /opt/xray-cluster/master  # 或 node
docker-compose pull
docker-compose up -d
```

### 3. 备份策略

**每日备份数据库**:
```bash
# 创建备份脚本
cat > /opt/xray-cluster/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/xray-cluster/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

cd /opt/xray-cluster/master
docker-compose exec -T postgres pg_dump -U xray_admin xray_cluster | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# 保留最近7天的备份
find $BACKUP_DIR -name "db_*.sql.gz" -mtime +7 -delete
EOF

chmod +x /opt/xray-cluster/backup.sh

# 添加到crontab
echo "0 2 * * * /opt/xray-cluster/backup.sh" | sudo crontab -
```

### 4. 监控告警

建议配置监控系统（如Prometheus + Grafana）监控：
- 节点在线状态
- 流量使用情况
- 系统资源使用
- 错误日志

## 故障排查

### Master无法访问

1. 检查Docker服务状态
```bash
docker-compose ps
```

2. 检查Caddy日志
```bash
docker-compose logs caddy
```

3. 检查域名解析
```bash
dig panel.example.com
```

### Node无法连接Master

1. 检查网络连接
```bash
curl -I https://panel.example.com
```

2. 检查Agent日志
```bash
docker-compose logs agent
```

3. 验证集群密钥是否正确
```bash
cat /opt/xray-cluster/node/.env | grep CLUSTER_SECRET
```

### Xray服务异常

1. 检查配置文件
```bash
cat /opt/xray-cluster/node/xray_config/config.json
```

2. 检查证书
```bash
ls -la /opt/xray-cluster/node/ssl/
```

3. 查看Xray日志
```bash
docker-compose logs xray
```

## 性能优化

### 1. 系统优化

```bash
# 优化网络参数
cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=134217728
net.core.wmem_max=134217728
EOF

sysctl -p
```

### 2. Docker优化

编辑 `/etc/docker/daemon.json`:
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### 3. 数据库优化

对于高负载场景，调整PostgreSQL配置：
```bash
# 编辑 docker-compose.yml 添加
environment:
  - POSTGRES_SHARED_BUFFERS=256MB
  - POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
  - POSTGRES_MAX_CONNECTIONS=200
```

## 升级指南

### 升级Master

```bash
cd /opt/xray-cluster/master

# 备份数据
./backup.sh

# 拉取最新代码
git pull

# 重新构建
docker-compose build --no-cache

# 重启服务
docker-compose up -d
```

### 升级Node

```bash
cd /opt/xray-cluster/node

# 拉取最新镜像
docker-compose pull

# 重启服务
docker-compose up -d
```

## 卸载

```bash
# 使用安装脚本卸载
sudo ./install.sh --uninstall

# 或手动卸载
cd /opt/xray-cluster/master && docker-compose down -v
cd /opt/xray-cluster/node && docker-compose down -v
sudo rm -rf /opt/xray-cluster
```

## 技术支持

- 文档: [README.md](README.md)
- 问题反馈: GitHub Issues
- 安全问题: security@example.com
