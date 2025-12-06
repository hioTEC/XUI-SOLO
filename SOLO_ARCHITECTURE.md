# SOLO 模式架构

## One Port Rule

只暴露端口 80 和 443，Xray 作为网关统一管理。

## 流量路由

```
客户端 → 443 端口 → Xray
                    ├─ VLESS 流量 → 代理
                    └─ HTTP 流量 → Caddy (127.0.0.1:8080)
                                   ├─ panel.domain → Web 面板
                                   └─ node.domain → 伪装站点
```

## 证书管理

Xray 管理两个域名的 SSL 证书：
- 面板域名：panel.example.com
- 节点域名：node.example.com

## 端口说明

- **443/TCP**: Xray 网关（对外）
- **80/TCP**: HTTP 重定向（对外）
- **8080/TCP**: Caddy 路由器（内部）
- **5000/TCP**: Web 应用（内部）
- **8081/TCP**: Agent API（内部）
