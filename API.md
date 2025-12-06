# Xray集群管理系统 - API文档

## 概述

本文档描述了Master节点和Worker节点之间的API接口规范。

## 认证机制

### HMAC-SHA256签名

所有API请求都需要使用HMAC-SHA256签名验证：

```python
import hmac
import hashlib
import json

def generate_signature(data, api_secret):
    """生成API签名"""
    message = json.dumps(data, sort_keys=True).encode()
    signature = hmac.new(
        api_secret.encode(),
        message,
        hashlib.sha256
    ).hexdigest()
    return signature
```

请求头格式：
```
X-Signature: <hmac_sha256_signature>
Content-Type: application/json
```

## Master API

Master节点提供以下API供Worker节点调用。

### 1. 节点注册

**端点**: `POST /api/node/register`

**描述**: Worker节点首次启动时向Master注册

**请求体**:
```json
{
  "token": "node-token-from-master",
  "timestamp": 1234567890
}
```

**响应**:
```json
{
  "node_id": 1,
  "api_secret": "generated-api-secret",
  "hidden_path": "abc123def456",
  "config": {
    "enable_vless": true,
    "enable_splithttp": false,
    "enable_hysteria2": false,
    "max_users": 100
  }
}
```

**状态码**:
- `200`: 注册成功
- `400`: 请求参数错误
- `401`: Token无效

**示例**:
```bash
curl -X POST https://panel.example.com/api/node/register \
  -H "Content-Type: application/json" \
  -d '{
    "token": "your-node-token",
    "timestamp": 1234567890
  }'
```

### 2. 心跳上报

**端点**: `POST /api/node/heartbeat`

**描述**: Worker节点定期发送心跳，上报状态和统计信息

**请求体**:
```json
{
  "node_id": 1,
  "api_secret": "your-api-secret",
  "timestamp": 1234567890,
  "stats": {
    "uptime": 86400,
    "connections": 15,
    "traffic_up": 1073741824,
    "traffic_down": 5368709120
  }
}
```

**响应**:
```json
{
  "status": "ok"
}
```

**状态码**:
- `200`: 心跳接收成功
- `400`: 请求参数错误
- `401`: 认证失败

**心跳间隔**: 建议60秒

**示例**:
```bash
curl -X POST https://panel.example.com/api/node/heartbeat \
  -H "Content-Type: application/json" \
  -d '{
    "node_id": 1,
    "api_secret": "your-api-secret",
    "timestamp": 1234567890,
    "stats": {
      "uptime": 86400,
      "connections": 15,
      "traffic_up": 1073741824,
      "traffic_down": 5368709120
    }
  }'
```

### 3. 获取配置

**端点**: `POST /api/node/config`

**描述**: Worker节点获取最新的Xray配置

**请求体**:
```json
{
  "node_id": 1,
  "api_secret": "your-api-secret"
}
```

**响应**:
```json
{
  "xray_config": "{...}",
  "config_version": "1.0"
}
```

**状态码**:
- `200`: 配置获取成功
- `400`: 请求参数错误
- `401`: 认证失败

## Worker Node API

Worker节点提供以下API供Master调用。

### 1. 健康检查

**端点**: `GET /health`

**描述**: 检查节点健康状态（无需认证）

**响应**:
```json
{
  "status": "ok",
  "registered": true,
  "xray_status": "running",
  "timestamp": 1234567890
}
```

**状态码**:
- `200`: 节点正常

**示例**:
```bash
curl https://node1.example.com/health
```

### 2. 重启Xray服务

**端点**: `POST /api/restart`

**描述**: 重启Xray服务

**请求头**:
```
X-Signature: <hmac_signature>
Content-Type: application/json
```

**请求体**:
```json
{
  "timestamp": 1234567890
}
```

**响应**:
```json
{
  "status": "ok",
  "message": "Xray重启成功"
}
```

**状态码**:
- `200`: 重启成功
- `400`: 请求参数错误
- `401`: 签名验证失败
- `500`: 重启失败

**示例**:
```python
import requests
import hmac
import hashlib
import json
import time

api_secret = "your-api-secret"
data = {"timestamp": int(time.time())}

signature = hmac.new(
    api_secret.encode(),
    json.dumps(data, sort_keys=True).encode(),
    hashlib.sha256
).hexdigest()

response = requests.post(
    "https://node1.example.com/api/restart",
    json=data,
    headers={"X-Signature": signature}
)
print(response.json())
```

### 3. 更新配置

**端点**: `POST /api/config`

**描述**: 更新Xray配置并重启服务

**请求头**:
```
X-Signature: <hmac_signature>
Content-Type: application/json
```

**请求体**:
```json
{
  "config": "{...xray config json...}",
  "timestamp": 1234567890
}
```

**响应**:
```json
{
  "status": "ok",
  "message": "配置更新成功"
}
```

**状态码**:
- `200`: 更新成功
- `400`: 配置格式错误
- `401`: 签名验证失败
- `500`: 更新失败

### 4. 获取日志

**端点**: `POST /api/logs`

**描述**: 获取Xray服务日志

**请求头**:
```
X-Signature: <hmac_signature>
Content-Type: application/json
```

**请求体**:
```json
{
  "lines": 100,
  "timestamp": 1234567890
}
```

**参数说明**:
- `lines`: 返回的日志行数（1-1000，默认100）

**响应**:
```json
{
  "status": "ok",
  "logs": "log content here..."
}
```

**状态码**:
- `200`: 获取成功
- `400`: 请求参数错误
- `401`: 签名验证失败
- `500`: 获取失败

### 5. 获取统计信息

**端点**: `POST /api/stats`

**描述**: 获取节点统计信息

**请求头**:
```
X-Signature: <hmac_signature>
Content-Type: application/json
```

**请求体**:
```json
{
  "timestamp": 1234567890
}
```

**响应**:
```json
{
  "status": "ok",
  "stats": {
    "uptime": 86400,
    "connections": 15,
    "traffic_up": 1073741824,
    "traffic_down": 5368709120,
    "xray_status": "running"
  }
}
```

**状态码**:
- `200`: 获取成功
- `401`: 签名验证失败

## 错误响应

所有API在发生错误时返回统一格式：

```json
{
  "error": "错误描述信息"
}
```

常见错误码：
- `400 Bad Request`: 请求参数错误
- `401 Unauthorized`: 认证失败
- `404 Not Found`: 资源不存在
- `500 Internal Server Error`: 服务器内部错误

## 安全注意事项

### 1. HTTPS强制

所有API通信必须使用HTTPS加密传输。

### 2. 签名验证

- 所有敏感操作必须验证HMAC签名
- 签名密钥（api_secret）必须安全存储
- 定期轮换API密钥

### 3. 时间戳验证

建议验证请求时间戳，防止重放攻击：

```python
import time

def verify_timestamp(timestamp, max_age=300):
    """验证时间戳（5分钟有效期）"""
    current_time = int(time.time())
    return abs(current_time - timestamp) <= max_age
```

### 4. 速率限制

建议实施API速率限制：
- 心跳API: 每分钟1次
- 配置API: 每分钟10次
- 日志API: 每分钟5次

### 5. IP白名单

建议配置IP白名单，只允许已知节点访问Master API。

## 完整示例

### Python客户端示例

```python
#!/usr/bin/env python3
import requests
import hmac
import hashlib
import json
import time

class XrayClusterClient:
    def __init__(self, master_url, api_secret):
        self.master_url = master_url
        self.api_secret = api_secret
    
    def _generate_signature(self, data):
        """生成HMAC签名"""
        message = json.dumps(data, sort_keys=True).encode()
        return hmac.new(
            self.api_secret.encode(),
            message,
            hashlib.sha256
        ).hexdigest()
    
    def register(self, token):
        """注册节点"""
        url = f"{self.master_url}/api/node/register"
        data = {
            "token": token,
            "timestamp": int(time.time())
        }
        
        response = requests.post(url, json=data)
        return response.json()
    
    def heartbeat(self, node_id, stats):
        """发送心跳"""
        url = f"{self.master_url}/api/node/heartbeat"
        data = {
            "node_id": node_id,
            "api_secret": self.api_secret,
            "timestamp": int(time.time()),
            "stats": stats
        }
        
        response = requests.post(url, json=data)
        return response.json()
    
    def get_config(self, node_id):
        """获取配置"""
        url = f"{self.master_url}/api/node/config"
        data = {
            "node_id": node_id,
            "api_secret": self.api_secret
        }
        
        response = requests.post(url, json=data)
        return response.json()

# 使用示例
if __name__ == "__main__":
    client = XrayClusterClient(
        master_url="https://panel.example.com",
        api_secret="your-api-secret"
    )
    
    # 注册节点
    result = client.register("your-node-token")
    print("注册结果:", result)
    
    # 发送心跳
    stats = {
        "uptime": 86400,
        "connections": 15,
        "traffic_up": 1073741824,
        "traffic_down": 5368709120
    }
    result = client.heartbeat(node_id=1, stats=stats)
    print("心跳结果:", result)
```

### cURL示例

```bash
#!/bin/bash

MASTER_URL="https://panel.example.com"
NODE_TOKEN="your-node-token"
API_SECRET="your-api-secret"

# 注册节点
curl -X POST "$MASTER_URL/api/node/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"token\": \"$NODE_TOKEN\",
    \"timestamp\": $(date +%s)
  }"

# 发送心跳
curl -X POST "$MASTER_URL/api/node/heartbeat" \
  -H "Content-Type: application/json" \
  -d "{
    \"node_id\": 1,
    \"api_secret\": \"$API_SECRET\",
    \"timestamp\": $(date +%s),
    \"stats\": {
      \"uptime\": 86400,
      \"connections\": 15,
      \"traffic_up\": 1073741824,
      \"traffic_down\": 5368709120
    }
  }"
```

## 版本历史

- **v1.0** (2024-12): 初始版本
  - 节点注册API
  - 心跳上报API
  - 配置管理API
  - 日志查询API
  - 统计信息API

## 技术支持

如有API相关问题，请查阅：
- [README.md](README.md) - 项目概述
- [DEPLOYMENT.md](DEPLOYMENT.md) - 部署指南
- GitHub Issues - 问题反馈
