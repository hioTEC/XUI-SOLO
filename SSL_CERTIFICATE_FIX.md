# SSL 证书问题修复说明

## 问题描述

用户在重新安装后遇到以下问题：
1. 浏览器提示"请求资源的方式不安全"
2. 证书文件大小为 0 字节
3. 无法访问管理面板

## 根本原因

之前的安装脚本只创建了空的占位符证书文件：
```bash
touch /opt/xray-cluster/node/certs/${panel_domain}.crt
touch /opt/xray-cluster/node/certs/${panel_domain}.key
```

这导致 Xray 虽然能启动，但 TLS 握手失败，浏览器无法建立安全连接。

## 修复方案

### 已实施的修复

修改了 `install.sh` 脚本，在安装时自动生成自签名证书：

```bash
# 为面板域名生成证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/xray-cluster/node/certs/${panel_domain}.key \
    -out /opt/xray-cluster/node/certs/${panel_domain}.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=${panel_domain}" \
    2>/dev/null

# 为节点域名生成证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/xray-cluster/node/certs/${node_domain}.key \
    -out /opt/xray-cluster/node/certs/${node_domain}.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=${node_domain}" \
    2>/dev/null

chmod 600 /opt/xray-cluster/node/certs/*.key
chmod 644 /opt/xray-cluster/node/certs/*.crt
```

### 用户操作指南

#### 方案 1：重新运行安装脚本（推荐）

```bash
# 使用最新的安装脚本重新安装（会保留配置）
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | \
    sudo bash -s -- --solo --panel panel.example.com --node-domain node.example.com
```

安装脚本会：
- 检测到现有安装
- 询问是否保留配置
- 自动生成有效的自签名证书
- 重启所有服务

#### 方案 2：手动生成证书

如果不想重新安装，可以手动生成证书：

```bash
# 进入证书目录
cd /opt/xray-cluster/node/certs

# 生成面板域名证书（替换为你的域名）
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout panel.example.com.key \
    -out panel.example.com.crt \
    -subj "/CN=panel.example.com"

# 生成节点域名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout node.example.com.key \
    -out node.example.com.crt \
    -subj "/CN=node.example.com"

# 设置权限
chmod 600 *.key
chmod 644 *.crt

# 验证证书文件
ls -lh

# 重启 Xray
cd /opt/xray-cluster/node
docker-compose restart xray

# 等待服务启动
sleep 5

# 测试连接
curl -I https://panel.example.com
```

#### 方案 3：获取正式 SSL 证书（生产环境推荐）

```bash
# 停止 Xray（释放 80 端口用于 ACME 验证）
cd /opt/xray-cluster/node
docker-compose stop xray

# 运行证书获取脚本
bash get-certs.sh

# 重启 Xray
docker-compose start xray
```

## 浏览器访问说明

### 使用自签名证书

浏览器会显示安全警告，这是正常的。操作步骤：

1. **Chrome/Edge**：
   - 点击「高级」
   - 点击「继续前往 panel.example.com（不安全）」

2. **Firefox**：
   - 点击「高级」
   - 点击「接受风险并继续」

3. **Safari**：
   - 点击「显示详细信息」
   - 点击「访问此网站」

### 使用正式证书

使用 acme.sh 获取的 Let's Encrypt 证书后，浏览器不会显示任何警告。

## 验证修复

运行以下命令验证证书是否正确生成：

```bash
# 1. 检查证书文件大小（应该大于 0）
ls -lh /opt/xray-cluster/node/certs/

# 2. 查看证书内容
openssl x509 -in /opt/xray-cluster/node/certs/panel.example.com.crt -text -noout | head -20

# 3. 检查 Xray 状态
cd /opt/xray-cluster/node
docker-compose ps

# 4. 检查端口监听
netstat -tlnp | grep :443

# 5. 测试 HTTPS 连接
curl -Ik https://panel.example.com
```

## 相关文件

- `install.sh` - 主安装脚本（已修复）
- `TROUBLESHOOTING.md` - 故障排查指南（已更新）
- `get-certs.sh` - 证书获取脚本（位于 /opt/xray-cluster/node/）

## 技术细节

### 自签名证书 vs 正式证书

| 特性 | 自签名证书 | Let's Encrypt 证书 |
|------|-----------|-------------------|
| 生成速度 | 即时 | 需要 DNS 验证（几分钟） |
| 浏览器信任 | ❌ 不信任 | ✅ 信任 |
| 适用场景 | 测试、开发 | 生产环境 |
| 有效期 | 365 天 | 90 天（自动续期） |
| 成本 | 免费 | 免费 |

### Xray TLS 配置

Xray 配置中的证书路径：
```json
{
  "streamSettings": {
    "security": "tls",
    "tlsSettings": {
      "certificates": [
        {
          "certificateFile": "/certs/node.example.com.crt",
          "keyFile": "/certs/node.example.com.key"
        },
        {
          "certificateFile": "/certs/panel.example.com.crt",
          "keyFile": "/certs/panel.example.com.key"
        }
      ]
    }
  }
}
```

Docker 卷挂载：
```yaml
volumes:
  - type: bind
    source: /opt/xray-cluster/node/certs
    target: /certs
    read_only: true
```

## 常见问题

### Q: 为什么不直接使用 Let's Encrypt？

A: Let's Encrypt 需要：
1. 域名已正确解析到服务器
2. 端口 80 可访问（用于 HTTP-01 验证）
3. 网络连接正常

在安装阶段，这些条件可能不满足，所以先用自签名证书确保服务能启动，用户可以稍后获取正式证书。

### Q: 自签名证书安全吗？

A: 自签名证书提供加密传输，但无法验证服务器身份。对于测试环境可以接受，生产环境建议使用正式证书。

### Q: 如何自动续期证书？

A: acme.sh 会自动设置 cron 任务，每 60 天检查并续期证书。无需手动操作。

## 总结

修复后的安装流程：
1. ✅ 安装时自动生成自签名证书
2. ✅ 证书文件有效（非空）
3. ✅ Xray 正常启动
4. ✅ 浏览器可以访问（需接受警告）
5. ✅ 用户可选择获取正式证书

用户现在可以：
- 立即访问面板（接受自签名证书警告）
- 或运行 `get-certs.sh` 获取正式证书
