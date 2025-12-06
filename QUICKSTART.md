# Xray集群管理系统 - 快速开始指南

## 🚀 5分钟快速部署

本指南将帮助你在5分钟内完成Xray集群的部署。

## 📋 准备工作

### 1. 服务器要求

- **操作系统**: Ubuntu 20.04+ / Debian 11+
- **内存**: 最低2GB（Master）/ 1GB（Worker）
- **磁盘**: 最低20GB
- **域名**: 需要2个域名（Master和Worker各一个）

### 2. 域名解析

确保域名已解析到服务器IP：

```bash
# Master域名
panel.example.com  →  123.123.123.123

# Worker域名
node1.example.com  →  124.124.124.124
```

### 3. 安装Docker

```bash
# 一键安装Docker
curl -fsSL https://get.docker.com | sh

# 启动Docker
sudo systemctl enable docker
sudo systemctl start docker

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## 📦 步骤1: 部署Master节点

### 在Master服务器上执行

```bash
# 1. 下载项目
git clone https://github.com/hioTEC/XUI-SOLO.git
cd XUI-SOLO

# 2. 运行安装脚本
sudo bash install.sh --master

# 3. 按提示输入信息
# - Master域名: panel.example.com
# - 自动生成集群密钥（请记录！）

# 4. 等待安装完成（约2-3分钟）
```

### 安装完成后

你会看到类似输出：

```
✓ Master节点安装完成!
访问地址: https://panel.example.com
管理员账号: admin
管理员密码: [自动生成的密码]
集群密钥: [请妥善保存此密钥]
```

**重要**: 请记录集群密钥，Worker节点需要使用！

## 📦 步骤2: 部署Worker节点

### 在Worker服务器上执行

```bash
# 1. 下载项目
git clone https://github.com/hioTEC/XUI-SOLO.git
cd XUI-SOLO

# 2. 运行安装脚本
sudo bash install.sh --node

# 3. 按提示输入信息
# - 集群密钥: [从Master获得的密钥]
# - Master域名: panel.example.com
# - 本节点域名: node1.example.com

# 4. 等待安装完成（约2-3分钟）
```

### 安装完成后

你会看到类似输出：

```
✓ Node节点安装完成!
节点域名: node1.example.com
API路径: /[随机路径]
Hysteria2端口: 50000
```

## 🎯 步骤3: 配置节点

### 1. 登录控制面板

访问: `https://panel.example.com`

使用安装时生成的管理员账号登录。

### 2. 添加节点

1. 点击左侧菜单 "节点管理"
2. 点击 "添加节点" 按钮
3. 填写节点信息：

```
节点名称: 美国节点1
服务器IP: 124.124.124.124
位置: 美国洛杉矶
描述: 高速节点
协议配置:
  ☑ VLESS+XTLS-Vision
  ☐ SplitHTTP
  ☐ Hysteria2
最大用户数: 100
```

4. 点击 "保存"
5. 记录生成的节点Token

### 3. 验证节点状态

- 在 "节点管理" 页面查看节点状态
- 状态应显示为 "在线" (绿色)
- 如果显示 "离线"，检查Worker节点日志

## 👥 步骤4: 添加用户

### 1. 创建用户账号

1. 点击左侧菜单 "用户管理"
2. 点击 "添加用户" 按钮
3. 填写用户信息：

```
用户名: user001
密码: [自动生成或手动输入]
邮箱: user@example.com
流量限制: 100GB
到期时间: 2025-12-31
分配节点: 美国节点1
```

4. 点击 "保存"

### 2. 生成配置链接

1. 在用户列表中找到刚创建的用户
2. 点击 "生成配置" 按钮
3. 复制配置链接或二维码
4. 发送给用户

## ✅ 验证部署

### 检查Master服务

```bash
cd /opt/xray-cluster/master
docker-compose ps

# 应该看到所有服务都是 "Up" 状态
```

### 检查Worker服务

```bash
cd /opt/xray-cluster/node
docker-compose ps

# 应该看到所有服务都是 "Up" 状态
```

### 测试连接

使用生成的配置链接，在客户端测试连接：

1. 导入配置到Xray客户端
2. 连接到节点
3. 测试网络连接
4. 检查IP地址是否为节点IP

## 🔧 常用管理命令

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

# 启动服务
docker-compose up -d
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

# 重启所有服务
docker-compose restart
```

## 🛡️ 安全配置

### 配置防火墙

**Master服务器**:
```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

**Worker服务器**:
```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 443/tcp   # VLESS
sudo ufw allow 443/udp   # VLESS UDP
sudo ufw allow 50000/udp # Hysteria2
sudo ufw enable
```

### 修改默认密码

1. 登录控制面板
2. 进入 "设置" 页面
3. 修改管理员密码
4. 使用强密码（至少12位，包含大小写字母、数字、特殊字符）

## 📊 监控和维护

### 查看仪表板

登录控制面板后，仪表板显示：

- 节点总数和在线数
- 用户总数
- 实时流量统计
- 节点状态列表

### 查看节点详情

1. 点击 "节点管理"
2. 点击节点名称
3. 查看详细信息：
   - 节点状态
   - 连接用户列表
   - 流量统计
   - 系统信息

### 查看日志

1. 点击节点详情页的 "查看日志"
2. 实时查看Xray运行日志
3. 用于故障排查

## 🔄 添加更多节点

重复 "步骤2: 部署Worker节点" 和 "步骤3: 配置节点"，可以添加任意数量的Worker节点。

建议：
- 不同地区部署多个节点
- 每个节点100-200用户
- 定期监控节点负载

## 📈 性能优化

### 启用BBR加速

```bash
# 在所有服务器上执行
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 优化网络参数

```bash
echo "net.core.rmem_max=134217728" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max=134217728" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## 🆘 故障排查

### Master无法访问

```bash
# 1. 检查服务状态
cd /opt/xray-cluster/master
docker-compose ps

# 2. 查看日志
docker-compose logs -f

# 3. 检查域名解析
dig panel.example.com

# 4. 检查防火墙
sudo ufw status
```

### Worker无法连接

```bash
# 1. 检查Agent日志
cd /opt/xray-cluster/node
docker-compose logs -f agent

# 2. 测试到Master的连接
curl -I https://panel.example.com

# 3. 检查集群密钥
cat /opt/xray-cluster/node/.env | grep CLUSTER_SECRET
```

### 用户无法连接

```bash
# 1. 检查Xray日志
docker-compose logs -f xray

# 2. 验证配置
docker-compose exec xray xray -test -config /etc/xray/config.json

# 3. 检查端口
sudo netstat -tulpn | grep 443
```

## 📚 更多资源

- **完整文档**: [README.md](README.md)
- **部署指南**: [DEPLOYMENT.md](DEPLOYMENT.md)
- **API文档**: [API.md](API.md)
- **开发指南**: [DEVELOPMENT.md](DEVELOPMENT.md)
- **项目状态**: [PROJECT_STATUS.md](PROJECT_STATUS.md)

## 💡 提示和技巧

### 1. 备份重要数据

```bash
# 备份Master数据库
cd /opt/xray-cluster/master
docker-compose exec postgres pg_dump -U xray_admin xray_cluster > backup.sql

# 备份配置文件
tar -czf config-backup.tar.gz /opt/xray-cluster/
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

### 3. 监控磁盘空间

```bash
# 查看磁盘使用
df -h

# 清理Docker
docker system prune -a
```

## 🎉 完成！

恭喜！你已经成功部署了Xray集群管理系统。

现在你可以：
- ✅ 管理多个Xray节点
- ✅ 创建和管理用户
- ✅ 监控流量和状态
- ✅ 远程控制节点

如有问题，请查看详细文档或提交Issue。

---

**下一步**:
1. 添加更多Worker节点
2. 配置自动备份
3. 设置监控告警
4. 优化性能参数

祝使用愉快！🚀
