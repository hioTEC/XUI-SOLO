# 重新安装指南

## 🔄 保留配置重新安装

安装脚本现在支持保留现有配置和数据，重新安装以修复问题。

### 快速重新安装

```bash
# 下载最新安装脚本
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" -o install.sh
chmod +x install.sh

# 运行安装（会提示是否保留配置）
sudo bash install.sh --solo
```

### 非交互式重新安装（保留配置）

如果你已经知道域名，可以直接指定：

```bash
sudo bash install.sh --solo --panel panel.hiomath.org --node-domain node.hiomath.org
```

脚本会自动：
1. ✅ 检测现有安装
2. ✅ 提示是否保留配置
3. ✅ 读取现有域名和密钥
4. ✅ 停止现有服务
5. ✅ 更新配置文件
6. ✅ 重建容器（应用修复）
7. ✅ 启动服务

## 🆕 本次更新内容

### 1. 修复 Python 依赖版本冲突
- Flask 3.0.0
- Flask-Login 0.6.3
- Werkzeug 3.0.1
- 其他依赖更新到兼容版本

### 2. 修复 Xray 启动命令
- 从 `xray run` 改为 `run`（正确的容器命令）

### 3. 自动安装 Docker Compose
- 检测并自动安装 Docker Compose V2
- 支持 `docker-compose` 和 `docker compose` 两种方式

### 4. 保留配置功能
- 自动读取现有域名
- 保留数据库密码
- 保留集群密钥
- 保留节点 UUID

### 5. 改进的 Caddyfile 路由
- 更宽容的路由匹配
- 默认转发到 Web 应用

## 📋 重新安装步骤

### 步骤 1：下载最新脚本

```bash
cd ~
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" -o install.sh
chmod +x install.sh
```

### 步骤 2：运行安装

```bash
sudo bash install.sh --solo
```

### 步骤 3：选择保留配置

当看到提示时：
```
[WARNING] 检测到已有安装
是否保留现有配置？(y/n):
```

输入 `y` 并按回车。

### 步骤 4：等待完成

脚本会：
- 读取现有配置
- 停止服务
- 更新文件
- 重建容器
- 启动服务

大约需要 2-3 分钟。

### 步骤 5：验证

```bash
# 检查服务状态
cd /opt/xray-cluster/master && docker-compose ps
cd /opt/xray-cluster/node && docker-compose ps

# 检查 Web 应用日志
cd /opt/xray-cluster/master
docker-compose logs web | tail -20

# 应该看到：
# [INFO] Booting worker with pid: XX
# [INFO] Worker booted successfully

# 测试访问
curl -I https://panel.hiomath.org
```

## 🔍 验证修复

### 1. Web 应用应该正常启动

```bash
cd /opt/xray-cluster/master
docker-compose logs web | grep "Worker booted"
```

应该看到：`[INFO] Worker booted successfully`

### 2. Xray 应该没有错误

```bash
cd /opt/xray-cluster/node
docker-compose logs xray | grep -i error
```

不应该看到 "unknown command" 错误。

### 3. 可以访问面板

```bash
curl -v http://127.0.0.1:8080 -H "Host: panel.hiomath.org"
```

应该返回 HTML 内容。

### 4. HTTPS 访问正常

在浏览器访问：`https://panel.hiomath.org`

应该看到登录页面。

## 🚨 如果仍有问题

### 问题：Web 应用仍然崩溃

```bash
# 手动重建 Web 容器
cd /opt/xray-cluster/master
docker-compose build --no-cache web
docker-compose up -d web
```

### 问题：Xray 仍然报错

```bash
# 检查配置
cd /opt/xray-cluster/node
docker-compose exec xray xray version

# 查看详细日志
docker-compose logs xray
```

### 问题：证书问题

```bash
# 重新获取证书
cd /opt/xray-cluster/node
docker-compose stop xray
bash get-certs.sh
docker-compose start xray
```

## 📊 保留的数据

重新安装时，以下数据会被保留：

✅ **保留**：
- 域名配置
- 管理员密码
- 数据库密码
- 集群密钥
- 节点 UUID
- PostgreSQL 数据（用户、节点等）
- Redis 数据
- SSL 证书

❌ **不保留**（会重新生成）：
- Docker 容器
- 应用代码
- 配置文件（会用新模板覆盖）

## 🔄 完全重新安装（不保留配置）

如果你想完全重新开始：

```bash
# 1. 完全卸载
sudo bash install.sh --uninstall

# 2. 删除所有数据
sudo rm -rf /opt/xray-cluster

# 3. 重新安装
sudo bash install.sh --solo --panel panel.hiomath.org --node-domain node.hiomath.org
```

## 📝 安装后

重新安装完成后：

1. 访问：`https://panel.hiomath.org`
2. 使用原来的管理员密码登录
3. 检查节点状态
4. 验证功能正常

如果忘记密码，查看：
```bash
cat /opt/xray-cluster/INSTALL_INFO.txt
```

---

**更新日期**：2024-12-06  
**版本**：1.1.0（修复版）
