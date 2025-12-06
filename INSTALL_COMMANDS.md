# XUI-SOLO Installation Commands

## Quick Reference

### ✅ Recommended: One-Line Installation with Two Domains

```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --solo --panel panel.example.com --node-domain node.example.com
```

Replace domains with your actual domains:
- `panel.example.com` - Admin control panel domain
- `node.example.com` - Proxy node domain

---

## All Installation Methods

### 1. SOLO Mode (Master + Local Worker)

#### Method A: One-Line with Domain (Non-Interactive)
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --solo --domain panel.example.com
```

#### Method B: Download and Run Interactively
```bash
# Download
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" -o install.sh
chmod +x install.sh

# Run (will prompt for domain)
sudo bash install.sh --solo
```

#### Method C: Download and Run with Domain
```bash
# Download
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" -o install.sh
chmod +x install.sh

# Run with domain parameter
sudo bash install.sh --solo --domain panel.example.com
```

#### Method D: Clone Repository
```bash
git clone https://github.com/hioTEC/XUI-SOLO.git
cd XUI-SOLO
sudo bash install.sh --solo --domain panel.example.com
```

---

### 2. Master Node Only

#### One-Line Installation
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --master
```

#### Download and Run
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" -o install.sh
chmod +x install.sh
sudo bash install.sh --master
```

---

### 3. Worker Node Only

#### One-Line Installation
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --node
```

#### Download and Run
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" -o install.sh
chmod +x install.sh
sudo bash install.sh --node
```

---

### 4. Interactive Menu

```bash
# Download
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" -o install.sh
chmod +x install.sh

# Run interactive menu
sudo bash install.sh
```

Then select:
- Option 1: SOLO Mode (Master + Local Worker)
- Option 2: Master Node Only
- Option 3: Worker Node Only

---

## Command Parameters

### Available Flags

- `--solo` - Install SOLO mode (Master + Local Worker)
- `--master` - Install Master node only
- `--node` - Install Worker node only
- `--domain <domain>` - Specify domain (required for non-interactive SOLO mode)
- `--uninstall` - Uninstall all services

### Examples

```bash
# SOLO with domain
sudo bash install.sh --solo --domain panel.example.com

# Master only (interactive)
sudo bash install.sh --master

# Worker only (interactive)
sudo bash install.sh --node

# Uninstall
sudo bash install.sh --uninstall
```

---

## Cache-Busting URLs

To ensure you always get the latest version:

### Method 1: Timestamp
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --solo --domain your-domain.com
```

### Method 2: Random Number
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?nocache=$RANDOM" | \
  sudo bash -s -- --solo --domain your-domain.com
```

### Method 3: wget with no-cache
```bash
wget --no-cache --no-cookies -O - \
  "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh" | \
  sudo bash -s -- --solo --domain your-domain.com
```

---

## Complete Examples

### Example 1: Fresh Ubuntu Server
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install with SOLO mode
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --solo --domain vpn.example.com

# Wait for installation to complete
# Access panel at: https://vpn.example.com
```

### Example 2: Distributed Setup

**On Master Server:**
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --master

# Save the cluster secret shown after installation
```

**On Worker Server 1:**
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --node

# Enter cluster secret when prompted
# Enter master domain when prompted
# Enter this node's domain when prompted
```

**On Worker Server 2:**
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --node

# Repeat the same process
```

---

## Troubleshooting

### Issue: "检测到通过管道运行，必须提供域名参数"

**Solution:** Add `--domain` parameter:
```bash
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --solo --domain your-domain.com
```

### Issue: DNS Check Failed

The installation will continue with a warning. Make sure:
1. Domain is correctly pointed to your server IP
2. DNS propagation is complete (can take up to 48 hours)
3. You can verify with: `dig your-domain.com`

### Issue: Docker Not Installed

The script will automatically install Docker. If it fails:
```bash
# Install Docker manually
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl start docker
sudo systemctl enable docker

# Then run the install script again
```

---

## Post-Installation

After successful installation:

1. **Access Control Panel**
   ```
   https://your-domain.com
   ```

2. **Find Credentials**
   ```bash
   cat /opt/xray-cluster/INSTALL_INFO.txt
   ```

3. **Check Service Status**
   ```bash
   cd /opt/xray-cluster/master
   docker-compose ps
   
   cd /opt/xray-cluster/node
   docker-compose ps
   ```

4. **View Logs**
   ```bash
   cd /opt/xray-cluster/master
   docker-compose logs -f
   ```

5. **Configure Firewall**
   ```bash
   sudo ufw allow 22/tcp   # SSH
   sudo ufw allow 80/tcp   # HTTP
   sudo ufw allow 443/tcp  # HTTPS
   sudo ufw allow 443/udp  # HTTPS UDP
   sudo ufw allow 50000/udp # Hysteria2
   sudo ufw enable
   ```

---

## Uninstallation

```bash
# Download and run uninstall
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --uninstall

# Or if you have the script
sudo bash install.sh --uninstall
```

---

## Quick Copy-Paste Commands

### For Testing (with common test domain):
```bash
# Replace test.example.com with your actual domain
export DOMAIN="test.example.com"

curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" | \
  sudo bash -s -- --solo --domain $DOMAIN
```

### For Production:
```bash
# Set your production domain
export DOMAIN="vpn.yourdomain.com"

# Download and inspect first (recommended)
curl -fsSL "https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh?$(date +%s)" -o install.sh
cat install.sh  # Review the script

# Run installation
sudo bash install.sh --solo --domain $DOMAIN
```

---

**Last Updated:** 2024-12-06  
**Repository:** https://github.com/hioTEC/XUI-SOLO
