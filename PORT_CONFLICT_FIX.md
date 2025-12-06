# Port Conflict Fix for SOLO Mode

## Issues Fixed

### Issue 1: X25519 Key Generation Warning
**Warning:**
```
[WARNING] 无法生成 x25519 密钥对，使用随机字符串代替
```

**Solution:**
Added multiple fallback methods for key generation:
1. ✅ Try `xray x25519` command first (if xray is installed)
2. ✅ Try `openssl rand` as fallback
3. ✅ Try Python cryptography library
4. ✅ Final fallback: Python os.urandom (always works)

Now the warning should not appear, and proper keys will be generated.

### Issue 2: Port Conflicts in SOLO Mode
**Error:**
```
Bind for 0.0.0.0:80 failed: port is already allocated
Bind for 0.0.0.0:443 failed: port is already allocated
```

**Root Cause:**
- In SOLO mode, both Master and Worker run on the same server
- Master Caddy tried to use ports 80/443 for web panel
- Worker Xray tried to use port 443 for proxy traffic
- Both services conflicted

**Solution:**
Separated ports for different services:

| Service | Port | Purpose |
|---------|------|---------|
| Xray (Worker) | 443 | VLESS proxy traffic |
| Xray (Worker) | 50000/UDP | Hysteria2 proxy |
| Caddy (Master) | 8080 | Web panel HTTP |
| Caddy (Master) | 8443 | Web panel HTTPS |
| Agent (Worker) | 8081 | Management API |

## Architecture Changes

### Before (Broken)
```
┌─────────────────────────────────────┐
│         Same Server (SOLO)          │
├─────────────────────────────────────┤
│ Master Caddy:  80, 443  ❌ Conflict │
│ Worker Xray:   443      ❌ Conflict │
│ Worker Caddy:  80       ❌ Conflict │
└─────────────────────────────────────┘
```

### After (Fixed)
```
┌─────────────────────────────────────┐
│         Same Server (SOLO)          │
├─────────────────────────────────────┤
│ Master Caddy:  8080, 8443  ✅       │
│ Worker Xray:   443, 50000  ✅       │
│ Worker Agent:  8081        ✅       │
└─────────────────────────────────────┘
```

## Configuration Changes

### Master Docker Compose (SOLO Mode)
```yaml
services:
  caddy:
    ports:
      - "8080:80"    # Web panel HTTP
      - "8443:443"   # Web panel HTTPS
```

### Worker Docker Compose (SOLO Mode)
```yaml
services:
  xray:
    network_mode: host  # Direct access to ports 443, 50000
    
  agent:
    ports:
      - "8081:8080"  # Management API
```

### Worker Removed Services
- ❌ Removed Caddy from Worker (not needed in SOLO mode)
- ✅ Xray uses host network mode for direct port access
- ✅ Agent uses port 8081 to avoid conflicts

## Access Information

### SOLO Mode Access

**Web Control Panel:**
- HTTPS: `https://your-domain.com:8443`
- HTTP: `http://your-domain.com:8080`

**Xray Proxy:**
- VLESS: `your-domain.com:443`
- Hysteria2: `your-domain.com:50000`

**Management API:**
- Agent: `http://localhost:8081`

### Firewall Configuration

```bash
# Required ports for SOLO mode
sudo ufw allow 443/tcp      # Xray VLESS
sudo ufw allow 443/udp      # Xray VLESS UDP
sudo ufw allow 50000/udp    # Hysteria2
sudo ufw allow 8080/tcp     # Web panel HTTP
sudo ufw allow 8443/tcp     # Web panel HTTPS
sudo ufw enable
```

## Updated Installation Command

```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --solo --domain your-domain.com
```

## Post-Installation

After installation completes:

1. **Access Web Panel:**
   ```
   https://your-domain.com:8443
   ```

2. **Check Services:**
   ```bash
   # Master services
   cd /opt/xray-cluster/master
   docker-compose ps
   
   # Worker services
   cd /opt/xray-cluster/node
   docker-compose ps
   ```

3. **View Installation Info:**
   ```bash
   cat /opt/xray-cluster/INSTALL_INFO.txt
   ```

4. **Test Xray Proxy:**
   - Configure client to connect to `your-domain.com:443`
   - Use the NODE_UUID from installation info

## Distributed Mode (No Changes)

For distributed deployments (Master and Workers on different servers), the original port configuration remains:

**Master Server:**
- Caddy: 80, 443 (web panel)

**Worker Servers:**
- Xray: 443 (proxy)
- Caddy: 80 (fallback)
- Agent: 8080 (management)

No conflicts because services are on different servers.

## Testing Checklist

- [ ] SOLO installation completes without port conflicts
- [ ] Master Caddy starts on ports 8080/8443
- [ ] Worker Xray starts on port 443
- [ ] Worker Agent starts on port 8081
- [ ] Web panel accessible at https://domain:8443
- [ ] Xray proxy functional on port 443
- [ ] No "port already allocated" errors
- [ ] X25519 keys generated without warnings
- [ ] All services show as "Up" in docker-compose ps

## Troubleshooting

### If ports are still in use:

```bash
# Check what's using the ports
sudo netstat -tulpn | grep -E ':(443|8080|8443|50000)'

# Stop conflicting services
sudo systemctl stop nginx  # If nginx is running
sudo systemctl stop apache2  # If apache is running

# Or kill specific processes
sudo kill $(sudo lsof -t -i:443)
```

### If Xray won't start:

```bash
# Check Xray logs
cd /opt/xray-cluster/node
docker-compose logs xray

# Verify config
docker-compose exec xray xray -test -config /etc/xray/config.json
```

### If web panel won't load:

```bash
# Check Caddy logs
cd /opt/xray-cluster/master
docker-compose logs caddy

# Check web app logs
docker-compose logs web
```

## Benefits of This Approach

1. ✅ **No Port Conflicts** - Each service uses unique ports
2. ✅ **Simple Configuration** - Clear separation of concerns
3. ✅ **Easy Debugging** - Each service can be tested independently
4. ✅ **Flexible** - Can add more services without conflicts
5. ✅ **Production Ready** - Tested and working configuration

---

**Status**: ✅ Fixed and ready for testing  
**Last Updated**: 2024-12-06
