# 依赖管理说明

## 自动依赖检查和安装

XUI-SOLO 的所有脚本都会自动检查并安装所需的依赖，无需手动操作。

## 主要依赖

### 安装脚本 (`install.sh`)

**必需依赖**：
- `curl` - 下载文件和 API 请求
- `git` - 克隆代码仓库
- `openssl` - 生成 SSL 证书
- `docker` - 容器运行环境
- `docker-compose` - 容器编排工具

**自动安装**：
- ✅ 如果缺失，脚本会自动检测操作系统并安装
- ✅ 支持 Ubuntu、Debian、CentOS、RHEL
- ✅ 安装失败会给出明确提示

**示例**：
```bash
# 运行安装脚本时，会自动检查并安装依赖
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | sudo bash

# 输出示例：
# [WARNING] 检测到缺失的工具: curl git openssl
# [INFO] 正在自动安装...
# [INFO] 安装 curl...
# [INFO] 安装 git...
# [INFO] 安装 openssl...
# [SUCCESS] 工具安装完成
```

---

### 证书获取脚本 (`get-certs.sh`)

**必需依赖**：
- `curl` - 下载 acme.sh
- `socat` - acme.sh standalone 模式需要
- `cron` - 证书自动续期
- `netstat` 或 `ss` - 检查端口占用

**自动安装**：
- ✅ 运行脚本时自动检查
- ✅ 缺失的依赖会自动安装
- ✅ 安装 acme.sh（如果未安装）

**示例**：
```bash
# 运行证书获取脚本
bash get-certs.sh

# 输出示例：
# [INFO] 检查依赖...
# [WARNING] socat 未安装，正在安装...
# [WARNING] cron 未安装，正在安装...
# [SUCCESS] 依赖检查完成
# [INFO] 安装 acme.sh...
# [SUCCESS] acme.sh 安装完成
```

---

## 依赖安装逻辑

### 1. 检测操作系统

```bash
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi
```

支持的操作系统：
- Ubuntu
- Debian
- CentOS
- RHEL

### 2. 选择包管理器

- **Debian/Ubuntu**: `apt-get`
- **CentOS/RHEL**: `yum`

### 3. 安装依赖

```bash
# Ubuntu/Debian
apt-get update
apt-get install -y curl git openssl socat cron net-tools

# CentOS/RHEL
yum install -y curl git openssl socat cronie net-tools
```

### 4. 启动服务

```bash
# 启动 cron 服务（用于证书自动续期）
systemctl enable cron
systemctl start cron
```

---

## 手动安装依赖

如果自动安装失败，可以手动安装：

### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y curl git openssl socat cron net-tools
```

### CentOS/RHEL

```bash
sudo yum install -y curl git openssl socat cronie net-tools
```

### Docker 和 Docker Compose

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
docker --version
docker compose version
```

---

## 依赖版本要求

### 最低版本

| 依赖 | 最低版本 | 推荐版本 |
|------|---------|---------|
| Docker | 20.10+ | 24.0+ |
| Docker Compose | 2.0+ | 2.20+ |
| curl | 7.0+ | 最新 |
| openssl | 1.1.1+ | 3.0+ |
| git | 2.0+ | 最新 |

### 检查版本

```bash
# Docker
docker --version

# Docker Compose
docker compose version

# curl
curl --version

# openssl
openssl version

# git
git --version
```

---

## 常见问题

### Q: 为什么需要 socat？

**A**: acme.sh 在 standalone 模式下使用 socat 来临时启动 HTTP 服务器，用于 Let's Encrypt 的 HTTP-01 验证。

### Q: 为什么需要 cron？

**A**: Let's Encrypt 证书有效期为 90 天，acme.sh 使用 cron 定时任务自动续期证书。

### Q: 可以不安装 git 吗？

**A**: 如果你手动下载了项目代码，可以不安装 git。但安装脚本会尝试使用 git 克隆代码，建议安装。

### Q: 自动安装失败怎么办？

**A**: 
1. 检查网络连接
2. 检查是否有 root 权限
3. 手动安装依赖（见上方手动安装部分）
4. 查看错误日志

### Q: 如何卸载依赖？

**A**: 不建议卸载系统依赖。如果确实需要：

```bash
# Ubuntu/Debian
sudo apt-get remove curl git openssl socat cron

# CentOS/RHEL
sudo yum remove curl git openssl socat cronie
```

**注意**：卸载这些工具可能影响其他程序。

---

## 依赖检查清单

安装前检查：

```bash
# 检查所有依赖
echo "=== 依赖检查 ==="
echo -n "curl: "; command -v curl && curl --version | head -1 || echo "未安装"
echo -n "git: "; command -v git && git --version || echo "未安装"
echo -n "openssl: "; command -v openssl && openssl version || echo "未安装"
echo -n "docker: "; command -v docker && docker --version || echo "未安装"
echo -n "docker-compose: "; docker compose version 2>/dev/null || echo "未安装"
echo -n "socat: "; command -v socat && socat -V 2>&1 | head -1 || echo "未安装"
echo -n "cron: "; command -v crontab && echo "已安装" || echo "未安装"
```

---

## 故障排查

### 依赖安装失败

**症状**：脚本提示"无法自动安装 xxx"

**解决方案**：
1. 检查网络连接
2. 更新包管理器缓存：
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   
   # CentOS/RHEL
   sudo yum clean all
   sudo yum makecache
   ```
3. 手动安装依赖
4. 重新运行脚本

### Docker 安装失败

**症状**：Docker 无法安装或启动

**解决方案**：
1. 查看官方文档：https://docs.docker.com/engine/install/
2. 检查系统版本是否支持
3. 检查内核版本：`uname -r`（需要 3.10+）
4. 查看错误日志：`journalctl -u docker`

### acme.sh 安装失败

**症状**：证书获取脚本无法安装 acme.sh

**解决方案**：
1. 检查网络连接
2. 手动安装：
   ```bash
   curl https://get.acme.sh | sh -s email=your@email.com
   ```
3. 查看 acme.sh 日志：`~/.acme.sh/acme.sh.log`

---

## 总结

- ✅ 所有脚本都会自动检查并安装依赖
- ✅ 支持主流 Linux 发行版
- ✅ 安装失败会给出明确提示
- ✅ 可以手动安装依赖后重新运行
- ✅ 无需担心依赖问题，脚本会处理一切

**建议**：使用全新的 Ubuntu 22.04 或 Debian 12 系统，依赖安装成功率最高。
