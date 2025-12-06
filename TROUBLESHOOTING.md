# 故障排查

## SSL 证书问题

### acme.sh 报错 "Cannot resolve _eab_id"

**原因**：acme.sh 默认使用 ZeroSSL，需要 EAB 认证

**解决**：
```bash
bash fix-ssl-now.sh
```

或手动修复：
```bash
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
cd /opt/xray-cluster/node && bash get-certs.sh
```

### 浏览器提示"不安全"

**原因**：使用自签名证书

**解决**：
1. 点击「高级」→「继续访问」
2. 或获取正式证书：`bash fix-ssl-now.sh`

### 证书文件为空

```bash
# 检查
ls -lh /opt/xray-cluster/node/certs/

# 重新生成
cd /opt/xray-cluster/node/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout panel.example.com.key -out panel.example.com.crt \
  -subj "/CN=panel.example.com"
chmod 600 *.key && chmod 644 *.crt
cd /opt/xray-cluster/node && docker-compose restart xray
```

## 服务问题

### 查看状态
```bash
cd /opt/xray-cluster/master && docker-compose ps
cd /opt/xray-cluster/node && docker-compose ps
```

### 查看日志
```bash
docker logs xray-node-xray
docker logs xray-master-web
```

### 端口检查
```bash
netstat -tlnp | grep -E ':(80|443)'
```

## 常见错误

### Xray 启动失败
```bash
# 检查配置
docker logs xray-node-xray

# 检查证书
ls -lh /opt/xray-cluster/node/certs/

# 重启
cd /opt/xray-cluster/node && docker-compose restart
```

### 端口 80 返回空白页面

**原因**：Xray 配置问题

**解决**：
```bash
bash fix-ssl-now.sh
```

### 端口被占用
```bash
netstat -tlnp | grep :443
systemctl stop nginx
```

### DNS 未解析
```bash
# 验证解析
dig panel.example.com
nslookup panel.example.com
```

## 完全重置

```bash
cd /opt/xray-cluster/master && docker-compose down -v
cd /opt/xray-cluster/node && docker-compose down -v
rm -rf /opt/xray-cluster
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | sudo bash
```
