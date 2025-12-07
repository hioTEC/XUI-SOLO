# HTTP/2 回落修复说明

## 问题根源
之前浏览器访问节点域名时出现 "Empty Response" 错误，是因为：
1. 浏览器通过 ALPN 协商使用 HTTP/2 (h2)
2. Xray 解密 TLS 后，发现是 h2 流量，但 fallbacks 中没有明确的 h2 处理规则
3. 即使回落到 Caddy，Caddy 的 80 端口默认只支持 HTTP/1.1，拒绝了 h2c (HTTP/2 over cleartext) 流量

## 修复方案

### ✅ 保留 Vision Flow
**VLESS + xtls-rprx-vision** 是对抗 GFW 主动探测的关键防护，已完整保留。

### 修改内容

#### 1. Xray 配置 (node/xray_config/config.json)
- ✅ 添加 ALPN 支持：`"alpn": ["h2", "http/1.1"]`
- ✅ 添加 h2 专用回落规则：
  ```json
  {
    "alpn": "h2",
    "dest": 80,
    "xver": 1
  }
  ```

#### 2. Caddy 配置 (node/Caddyfile)
- ✅ 全局开启 h2c 支持：
  ```caddyfile
  {
    servers :80 {
      protocols h1 h2c
    }
  }
  ```

#### 3. install.sh
- ✅ 更新普通 Node 模式的配置生成
- ✅ 更新 SOLO 模式的配置生成

## 工作原理

1. **浏览器访问** → TLS 握手，ALPN 协商 h2
2. **Xray 接收** → 识别为非 VLESS 流量，触发 fallback
3. **匹配 h2 规则** → 根据 `"alpn": "h2"` 规则，转发到 Caddy:80
4. **Caddy 处理** → 因为开启了 h2c 支持，成功接收并响应 HTTP/2 流量
5. **浏览器显示** → 正常显示伪装网站内容

## 安全性
- ✅ Vision Flow 完整保留，对抗主动探测能力不变
- ✅ TLS 加密正常工作
- ✅ 流量特征更加自然（支持现代浏览器的 HTTP/2）

## 部署说明
如果已经部署了节点，需要：
1. 更新 `node/xray_config/config.json`
2. 创建/更新 `node/Caddyfile`
3. 重启 Xray 和 Caddy 容器
