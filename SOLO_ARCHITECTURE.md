# SOLO Mode Architecture - "One Port Rule"

## Design Philosophy

**Only ports 80 and 443 are exposed to the public internet.**

Xray-core acts as the **gatekeeper** on port 443, managing SSL certificates for both domains and routing all traffic.

## Architecture Diagram

```
Internet
   │
   ├─── Port 80 ────────────────────────────────┐
   │                                             │
   └─── Port 443 ───────────────────────────────┤
                                                 │
                                                 ▼
                                        ┌─────────────────┐
                                        │   Xray-core     │
                                        │  (Gatekeeper)   │
                                        │   Port 443      │
                                        │                 │
                                        │  Manages TLS:   │
                                        │  - panel.com    │
                                        │  - node.com     │
                                        └────────┬────────┘
                                                 │
                        ┌────────────────────────┼────────────────────────┐
                        │                        │                        │
                   VLESS Proxy              Fallback                  HTTP (80)
                   (node.com)            (All non-proxy)            (Redirect)
                        │                        │                        │
                        ▼                        ▼                        ▼
                  ┌──────────┐          ┌──────────────┐          ┌──────────┐
                  │  Proxy   │          │    Caddy     │          │  Caddy   │
                  │ Traffic  │          │ (Router)     │          │  (HTTP)  │
                  │          │          │ 127.0.0.1    │          │          │
                  └──────────┘          │   :8080      │          └──────────┘
                                        └──────┬───────┘
                                               │
                                ┌──────────────┼──────────────┐
                                │              │              │
                          Host: panel.com  Host: node.com  Other
                                │              │              │
                                ▼              ▼              ▼
                        ┌──────────────┐ ┌──────────┐  ┌─────────┐
                        │  Web Panel   │ │  Fake    │  │   404   │
                        │  (Flask)     │ │  Site +  │  │         │
                        │  :5000       │ │  Agent   │  │         │
                        └──────────────┘ └──────────┘  └─────────┘
```

## Traffic Flow

### 1. Admin Panel Access
```
User Browser → https://panel.example.com:443
    ↓
Xray (TLS Termination, panel.example.com cert)
    ↓
Xray Fallback → 127.0.0.1:8080
    ↓
Caddy (Host: panel.example.com)
    ↓
Reverse Proxy → web:5000
    ↓
Flask Web Application
```

### 2. Proxy Traffic (VLESS)
```
Xray Client → vless://node.example.com:443
    ↓
Xray (TLS + VLESS Protocol)
    ↓
Proxy to Internet
```

### 3. Fake Website (Browser to Node Domain)
```
User Browser → https://node.example.com:443
    ↓
Xray (TLS Termination, node.example.com cert)
    ↓
Xray Fallback → 127.0.0.1:8080
    ↓
Caddy (Host: node.example.com)
    ↓
Static Website / Agent API
```

## Component Configuration

### 1. Xray-core (The Gatekeeper)

**Location**: `/opt/xray-cluster/node/xray_config/config.json`

**Key Features**:
- Listens on `0.0.0.0:443` (host network mode)
- Manages SSL certificates for **both** domains
- VLESS protocol with xtls-rprx-vision
- Fallback to `127.0.0.1:8080` for non-proxy traffic
- Port 80 redirect to Caddy

**Configuration**:
```json
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [...],
        "fallbacks": [
          {
            "dest": "127.0.0.1:8080",
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/certs/node.example.com.crt",
              "keyFile": "/etc/xray/certs/node.example.com.key"
            },
            {
              "certificateFile": "/etc/xray/certs/panel.example.com.crt",
              "keyFile": "/etc/xray/certs/panel.example.com.key"
            }
          ]
        }
      }
    },
    {
      "port": 80,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1",
        "port": 8080
      }
    }
  ]
}
```

### 2. Caddy (The Router)

**Location**: `/opt/xray-cluster/master/Caddyfile`

**Key Features**:
- Listens on `127.0.0.1:8080` (internal only)
- Routes based on Host header
- No external ports exposed

**Configuration**:
```caddyfile
:8080 {
    # Panel domain → Web application
    @panel host panel.example.com
    handle @panel {
        reverse_proxy web:5000
    }
    
    # Node domain → Fake site + Agent API
    @node host node.example.com
    handle @node {
        handle_path /api/* {
            reverse_proxy 127.0.0.1:8081
        }
        handle {
            respond "Welcome" 200
        }
    }
    
    # Other → 404
    handle {
        respond "404 Not Found" 404
    }
}
```

### 3. Docker Compose Configuration

**Master** (`/opt/xray-cluster/master/docker-compose.yml`):
```yaml
services:
  caddy:
    ports:
      - "127.0.0.1:8080:8080"  # Internal only
    
  web:
    # No external ports
    
  postgres:
    # No external ports
    
  redis:
    # No external ports
```

**Worker** (`/opt/xray-cluster/node/docker-compose.yml`):
```yaml
services:
  xray:
    network_mode: host  # Direct access to ports 80, 443
    
  agent:
    ports:
      - "127.0.0.1:8081:8080"  # Internal only
```

## Installation

### Command Format

```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --solo --panel panel.example.com --node-domain node.example.com
```

### Parameters

- `--solo` - Enable SOLO mode
- `--panel <domain>` - Admin panel domain (e.g., `panel.example.com`)
- `--node-domain <domain>` - Node/proxy domain (e.g., `node.example.com`)

### Installation Steps

1. **Run Installation Script**
   ```bash
   sudo bash install.sh --solo --panel panel.com --node-domain node.com
   ```

2. **Get SSL Certificates**
   ```bash
   cd /opt/xray-cluster/node
   bash get-certs.sh
   ```
   
   This script uses `acme.sh` to obtain certificates for both domains.

3. **Restart Services**
   ```bash
   cd /opt/xray-cluster/node
   docker-compose restart xray
   ```

4. **Access Panel**
   ```
   https://panel.example.com
   ```

## Port Usage

| Port | Service | Exposed | Purpose |
|------|---------|---------|---------|
| 80 | Xray | ✅ Public | HTTP redirect, ACME challenge |
| 443 | Xray | ✅ Public | HTTPS gateway (TLS + VLESS) |
| 8080 | Caddy | ❌ Internal | HTTP router (127.0.0.1 only) |
| 8081 | Agent | ❌ Internal | Management API (127.0.0.1 only) |
| 5000 | Web | ❌ Internal | Flask application (Docker network) |
| 5432 | PostgreSQL | ❌ Internal | Database (Docker network) |
| 6379 | Redis | ❌ Internal | Cache (Docker network) |

## Firewall Configuration

```bash
# Only these ports need to be open
sudo ufw allow 80/tcp    # HTTP (ACME, redirects)
sudo ufw allow 443/tcp   # HTTPS (Xray gateway)
sudo ufw allow 443/udp   # HTTPS UDP (optional)
sudo ufw enable
```

## Security Features

1. **Minimal Attack Surface**
   - Only ports 80 and 443 exposed
   - All management interfaces internal only

2. **TLS Everywhere**
   - Xray manages all TLS certificates
   - Automatic certificate renewal via acme.sh

3. **Host-Based Routing**
   - Different domains route to different services
   - Unknown hosts get 404

4. **Network Isolation**
   - Docker networks isolate services
   - Only Xray has host network access

5. **Fallback Protection**
   - Non-proxy traffic goes to Caddy
   - Caddy validates Host header
   - Invalid requests get 404

## Certificate Management

### Initial Setup

```bash
cd /opt/xray-cluster/node
bash get-certs.sh
```

### Manual Certificate Renewal

```bash
~/.acme.sh/acme.sh --renew -d panel.example.com
~/.acme.sh/acme.sh --renew -d node.example.com
cd /opt/xray-cluster/node && docker-compose restart xray
```

### Automatic Renewal

Add to crontab:
```bash
0 0 * * * /opt/xray-cluster/node/get-certs.sh
```

## Troubleshooting

### Check Xray Status
```bash
cd /opt/xray-cluster/node
docker-compose logs xray
```

### Check Certificate Files
```bash
ls -la /opt/xray-cluster/node/certs/
```

### Test Fallback
```bash
# Should route to Caddy
curl -H "Host: panel.example.com" http://127.0.0.1:8080
```

### Verify Port Binding
```bash
sudo netstat -tulpn | grep -E ':(80|443|8080|8081)'
```

## Advantages of This Architecture

1. ✅ **Clean Port Usage** - Only 80/443 exposed
2. ✅ **Single TLS Termination** - Xray handles all certificates
3. ✅ **Flexible Routing** - Easy to add more domains
4. ✅ **Better Security** - Minimal attack surface
5. ✅ **Standard Ports** - No weird ports like 8443
6. ✅ **Professional** - Looks like a normal HTTPS service
7. ✅ **Scalable** - Easy to add more services behind Caddy

## Comparison: Old vs New

### Old Architecture (REJECTED)
```
❌ Port 8443 → Master Panel
❌ Port 443 → Xray
❌ Port 8080 → Master Panel HTTP
❌ Multiple external ports
❌ Non-standard ports
```

### New Architecture (APPROVED)
```
✅ Port 443 → Xray (Gateway)
    ├─ panel.com → Caddy → Web Panel
    ├─ node.com (VLESS) → Proxy
    └─ node.com (HTTP) → Caddy → Fake Site
✅ Port 80 → Xray → Caddy (HTTP redirect)
✅ Only standard ports
✅ Single entry point
```

---

**Status**: ✅ Implemented  
**Architecture**: One Port Rule  
**Last Updated**: 2024-12-06
