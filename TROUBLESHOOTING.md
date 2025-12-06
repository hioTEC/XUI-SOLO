# 故障排查指南 - 无法访问面板

## 问题：Safari浏览器无法打开页面

错误信息：`Safari浏览器无法打开页面"https://panel.hiomath.org"，因为服务器意外中断了连接`

## 诊断步骤

### 1. 检查所有服务状态

```bash
# 检查 Master 服务
cd /opt/xray-cluster/master
docker-compose ps

# 检查 Worker 服务
cd /opt/xray-cluster/node
docker-compose ps
```

**期望输出**：所有服务应该显示 `Up` 状态

### 2. 检查 Xray 日志

```bash
cd /opt/xray-cluster/node
docker-compose logs xray
```

**常见问题**：
- ❌ 证书文件不存在或为空
- ❌ 配置文件语法错误
- ❌ 端口被占用

### 3. 检查证书文件

```bash
ls -lh /opt/xray-cluster/node/certs/
```

**问题**：如果证书文件大小为 0 字节，说明还没有获取真实证书。

**解决方案**：
```bash
cd /opt/xray-cluster/node
bash get-certs.sh
```

### 4. 检查端口监听

```bash
sudo netstat -tulpn | grep -E ':(80|443|8080|8081)'
```

**期望输出**：
```
tcp  0.0.0.0:80    LISTEN  xray
tcp  0.0.0.0:443   LISTEN  xray
tcp  127.0.0.1:8080  LISTEN  caddy
tcp  127.0.0.1:8081  LISTEN  agent
```

### 5. 检查 Caddy 日志

```bash
cd /opt/xray-cluster/master
docker-compose logs caddy
```

### 6. 检查 Web 应用日志

```bash
cd /opt/xray-cluster/master
docker-compose logs web
```

## 最可能的原因：缺少 SSL 证书

由于安装脚本只创建了占位符证书文件（空文件），Xray 无法正常启动 TLS。

### 立即修复步骤

#### 方案 1：获取真实证书（推荐）

```bash
# 1. 停止 Xray（释放 80 端口用于 ACME 验证）
cd /opt/xray-cluster/node
docker-compose stop xray

# 2. 获取证书
bash get-certs.sh

# 3. 重启 Xray
docker-compose start xray

# 4. 等待几秒后测试
sleep 5
curl -I https://panel.hiomath.org
```

#### 方案 2：使用自签名证书（临时测试）

```bash
# 生成自签名证书
cd /opt/xray-cluster/node/certs

# 面板域名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout panel.hiomath.org.key \
  -out panel.hiomath.org.crt \
  -subj "/CN=panel.hiomath.org"

# 节点域名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout node.hiomath.org.key \
  -out node.hiomath.org.crt \
  -subj "/CN=node.hiomath.org"

# 设置权限
chmod 600 *.key

# 重启 Xray
cd /opt/xray-cluster/node
docker-compose restart xray
```

**注意**：自签名证书会导致浏览器显示安全警告，但可以用于测试。

## 详细诊断命令

### 完整诊断脚本

```bash
#!/bin/bash

echo "=== XUI-SOLO 诊断报告 ==="
echo ""

echo "1. 检查服务状态"
echo "Master 服务:"
cd /opt/xray-cluster/master && docker-compose ps
echo ""
echo "Worker 服务:"
cd /opt/xray-cluster/node && docker-compose ps
echo ""

echo "2. 检查端口监听"
sudo netstat -tulpn | grep -E ':(80|443|8080|8081)'
echo ""

echo "3. 检查证书文件"
ls -lh /opt/xray-cluster/node/certs/
echo ""

echo "4. 检查 Xray 配置"
cd /opt/xray-cluster/node
docker-compose exec xray xray -test -config /etc/xray/config.json 2>&1 | head -20
echo ""

echo "5. 检查最近的错误日志"
echo "Xray 错误:"
docker-compose logs xray 2>&1 | grep -i error | tail -10
echo ""
echo "Caddy 错误:"
cd /opt/xray-cluster/master
docker-compose logs caddy 2>&1 | grep -i error | tail -10
echo ""

echo "6. 测试内部连接"
echo "测试 Caddy (应该返回 200 或 404):"
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080
echo ""

echo "=== 诊断完成 ==="
```

保存为 `diagnose.sh` 并运行：
```bash
chmod +x diagnose.sh
bash diagnose.sh
```

## 常见问题和解决方案

### 问题 1：证书文件为空

**症状**：
```bash
$ ls -lh /opt/xray-cluster/node/certs/
-rw-r--r-- 1 root root 0 Dec  6 10:00 panel.hiomath.org.crt
-rw------- 1 root root 0 Dec  6 10:00 panel.hiomath.org.key
```

**解决**：
```bash
cd /opt/xray-cluster/node
docker-compose stop xray
bash get-certs.sh
docker-compose start xray
```

### 问题 2：Xray 无法启动

**症状**：
```
xray-node-xray | Failed to load config: ...
```

**解决**：
```bash
# 检查配置语法
cd /opt/xray-cluster/node
docker-compose exec xray xray -test -config /etc/xray/config.json

# 查看详细错误
docker-compose logs xray | tail -50
```

### 问题 3：端口被占用

**症状**：
```
Bind for 0.0.0.0:443 failed: port is already allocated
```

**解决**：
```bash
# 查看占用端口的进程
sudo netstat -tulpn | grep :443

# 停止占用的服务（例如 nginx）
sudo systemctl stop nginx
sudo systemctl disable nginx

# 重启 Xray
cd /opt/xray-cluster/node
docker-compose restart xray
```

### 问题 4：DNS 未解析

**症状**：
```bash
$ dig panel.hiomath.org
# 没有返回 A 记录
```

**解决**：
1. 登录域名服务商
2. 添加 A 记录：
   - `panel.hiomath.org` → 服务器 IP
   - `node.hiomath.org` → 服务器 IP
3. 等待 DNS 传播（最多 48 小时，通常几分钟）

### 问题 5：防火墙阻止

**症状**：
```bash
$ curl -I https://panel.hiomath.org
curl: (7) Failed to connect to panel.hiomath.org port 443: Connection refused
```

**解决**：
```bash
# 检查防火墙状态
sudo ufw status

# 开放必要端口
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

## 快速修复流程

### 最快的修复方法（5 分钟）

```bash
# 1. 停止 Xray
cd /opt/xray-cluster/node
docker-compose stop xray

# 2. 获取证书
bash get-certs.sh

# 3. 如果证书获取失败，使用自签名证书
if [ ! -s /opt/xray-cluster/node/certs/panel.hiomath.org.crt ]; then
    cd /opt/xray-cluster/node/certs
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout panel.hiomath.org.key \
      -out panel.hiomath.org.crt \
      -subj "/CN=panel.hiomath.org"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout node.hiomath.org.key \
      -out node.hiomath.org.crt \
      -subj "/CN=node.hiomath.org"
    chmod 600 *.key
fi

# 4. 重启所有服务
cd /opt/xray-cluster/node
docker-compose restart

cd /opt/xray-cluster/master
docker-compose restart

# 5. 等待服务启动
sleep 10

# 6. 测试
curl -I https://panel.hiomath.org
```

## 验证修复

修复后，运行以下命令验证：

```bash
# 1. 所有服务应该运行
cd /opt/xray-cluster/master && docker-compose ps
cd /opt/xray-cluster/node && docker-compose ps

# 2. 端口应该监听
sudo netstat -tulpn | grep -E ':(443|8080)'

# 3. 证书文件应该有内容
ls -lh /opt/xray-cluster/node/certs/

# 4. 可以访问面板
curl -I https://panel.hiomath.org
```

## 获取帮助

如果问题仍未解决，请收集以下信息：

```bash
# 生成诊断报告
cd /opt/xray-cluster
tar -czf debug-info.tar.gz \
  master/docker-compose.yml \
  node/docker-compose.yml \
  node/xray_config/config.json \
  INSTALL_INFO.txt

# 收集日志
cd /opt/xray-cluster/master && docker-compose logs > /tmp/master-logs.txt
cd /opt/xray-cluster/node && docker-compose logs > /tmp/node-logs.txt

# 系统信息
uname -a > /tmp/system-info.txt
docker version >> /tmp/system-info.txt
docker-compose version >> /tmp/system-info.txt
```

然后提交 Issue 并附上这些文件。

---

**最常见的问题**：缺少 SSL 证书  
**最快的解决方案**：运行 `bash get-certs.sh` 或使用自签名证书
