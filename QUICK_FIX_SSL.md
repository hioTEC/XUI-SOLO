# 快速修复：浏览器提示"请求资源的方式不安全"

## 问题

安装完成后，浏览器显示：
- "您的连接不是私密连接"
- "请求资源的方式不安全"
- "此连接不是私密连接"

## 原因

使用的是自签名 SSL 证书，浏览器不信任。

## 解决方案（3选1）

### 方案 1：直接访问（最快，1分钟）

**推荐用于测试和快速访问**

1. 在浏览器警告页面点击「高级」或「详细信息」
2. 点击「继续访问」或「接受风险并继续」
3. 完成！可以正常使用面板

**说明**：自签名证书仍然提供加密传输，只是浏览器无法验证服务器身份。

---

### 方案 2：获取正式证书（推荐，5分钟）

**推荐用于生产环境**

```bash
# 方式 A：使用安装时生成的脚本
cd /opt/xray-cluster/node
bash get-certs.sh

# 方式 B：使用项目根目录的脚本
bash get-certs.sh 面板域名 节点域名
```

**说明**：
- ✅ 脚本会自动检查并安装所需依赖（curl, socat, cron 等）
- ✅ 自动停止 Xray 释放 80 端口
- ✅ 自动获取证书并安装
- ✅ 自动重启 Xray 服务

**前提条件**：
- 域名已正确解析到服务器 IP
- 端口 80 可从公网访问
- 服务器可以连接到 Let's Encrypt

---

### 方案 3：重新安装（如果证书损坏，10分钟）

**仅在证书文件损坏或为空时使用**

```bash
# 检查证书是否损坏
ls -lh /opt/xray-cluster/node/certs/

# 如果文件大小为 0，重新安装（会保留配置）
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | \
    sudo bash -s -- --solo --panel 你的面板域名 --node-domain 你的节点域名
```

安装时选择「保留现有配置」，脚本会自动生成新的自签名证书。

---

## 验证修复

### 检查证书文件

```bash
# 证书文件应该有内容（大于 0 字节）
ls -lh /opt/xray-cluster/node/certs/

# 应该看到类似：
# -rw-r--r-- 1 root root 1.3K Dec  6 10:00 panel.example.com.crt
# -rw------- 1 root root 1.7K Dec  6 10:00 panel.example.com.key
```

### 检查 Xray 状态

```bash
cd /opt/xray-cluster/node
docker-compose ps

# xray-node-xray 应该显示 "Up"
```

### 测试连接

```bash
# 应该返回 HTTP 状态码（如 200, 301, 404 等）
curl -Ik https://你的面板域名
```

---

## 常见问题

### Q: 方案1安全吗？

A: 自签名证书提供加密传输，数据不会被窃听。只是无法验证服务器身份。对于自己的服务器，这是安全的。

### Q: 为什么不默认使用正式证书？

A: 正式证书需要域名解析和网络验证，安装时可能不满足条件。自签名证书确保服务能立即启动。

### Q: 如何自动续期证书？

A: 使用 acme.sh 获取的证书会自动续期，无需手动操作。

### Q: 可以使用自己的证书吗？

A: 可以。将证书文件复制到 `/opt/xray-cluster/node/certs/`，文件名格式：
- `你的域名.crt` - 证书文件
- `你的域名.key` - 私钥文件

然后重启 Xray：
```bash
cd /opt/xray-cluster/node
docker-compose restart xray
```

---

## 推荐流程

1. **立即访问**：使用方案1，接受自签名证书警告
2. **登录面板**：使用默认账号密码（见安装信息）
3. **配置系统**：添加节点、用户等
4. **获取证书**：使用方案2，获取正式证书
5. **刷新浏览器**：警告消失，正常使用

---

## 需要帮助？

查看详细故障排查指南：`TROUBLESHOOTING.md`

或查看完整修复说明：`SSL_CERTIFICATE_FIX.md`
