# SSL 证书快速修复

## 快速修复（推荐）

```bash
bash fix-ssl-now.sh
```

自动修复所有 SSL 问题，包括：
- 修复 Xray 配置
- 切换到 Let's Encrypt
- 获取或生成证书
- 重启服务

## 手动方案

### 方案 1：接受警告（最快）
点击「高级」→「继续访问」

### 方案 2：获取正式证书
```bash
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
cd /opt/xray-cluster/node && bash get-certs.sh
```

### 方案 3：重新安装
```bash
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | \
    sudo bash -s -- --solo --panel 面板域名 --node-domain 节点域名
```

## 验证

```bash
# 检查证书
ls -lh /opt/xray-cluster/node/certs/

# 检查服务
cd /opt/xray-cluster/node && docker-compose ps

# 测试连接
curl -Ik https://面板域名
```
