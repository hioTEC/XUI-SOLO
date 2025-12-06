# Changelog

## [1.1.0] - 2024-12-06

### Added - SOLO Mode

#### 🎯 New SOLO Deployment Mode
- **One-Click Deployment**: New `--solo` flag for unified Master + Worker deployment
- **Automatic Worker Setup**: Master automatically deploys and registers a local Worker node
- **Zero Configuration**: Intelligent defaults for immediate production use
- **Single Domain**: Both Master and Worker share the same domain for simplified setup

#### 📝 README Overhaul
- **Repositioned Content**: SOLO mode and one-click deployment now at the top
- **Enhanced Security Section**: Comprehensive 7-layer security architecture documentation
- **Improved Structure**: 
  - Product positioning emphasized
  - Security features highlighted
  - Deployment simplicity showcased
  - Quick start moved to beginning

#### 🔧 Installation Script Enhancements
- Added `install_solo()` function for integrated deployment
- Automatic credential generation and secure storage
- Installation info saved to `/opt/xray-cluster/INSTALL_INFO.txt`
- Interactive menu updated with SOLO as option #1 (recommended)

### Changed

#### README.md
- Moved "One-Click Deployment" section to top (after positioning)
- Expanded "Core Security Features" with detailed 7-layer protection
- Reorganized table of contents to prioritize deployment and security
- Enhanced "Product Positioning" section with clear value propositions
- Improved "Usage Guide" with SOLO-specific instructions
- Added "Security Best Practices" section with deployment checklist
- Streamlined "Troubleshooting" with quick diagnostics

#### install.sh
- Added `--solo` command-line flag support
- SOLO mode creates both Master and Worker configurations
- Automatic service orchestration (Master starts first, then Worker)
- Comprehensive installation summary with all credentials
- Menu system updated: SOLO is now option 1 (recommended)

### Security Highlights

The README now prominently features:
1. **Transport Layer Security**: HTTPS/TLS 1.3, automatic certificates
2. **API Security**: HMAC-SHA256 signatures, timestamp validation
3. **Input Security**: Regex validation, path traversal protection
4. **Command Execution Security**: Whitelist, parameter validation, no shell injection
5. **Network Security**: Docker isolation, minimal port exposure
6. **Application Security**: CSP, CSRF protection, security headers
7. **Audit & Monitoring**: Operation logs, access logs, anomaly detection

### Documentation

- New emphasis on "Security First" philosophy
- Clear differentiation between SOLO and distributed deployment modes
- Step-by-step security hardening checklist
- Improved troubleshooting with quick diagnostic commands
- Enhanced API documentation section

### Installation Examples

```bash
# SOLO Mode (New!)
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | sudo bash -s -- --solo

# Or with git clone
git clone https://github.com/hioTEC/XUI-SOLO.git
cd XUI-SOLO
sudo bash install.sh --solo
```

### Breaking Changes
None - All existing deployment methods remain fully supported

### Migration Guide
Existing installations are not affected. SOLO mode is a new deployment option that complements existing Master/Worker installation methods.

---

## [1.0.0] - 2024-12-06

### Initial Release
- Master-Worker distributed architecture
- Multi-protocol support (VLESS, SplitHTTP, Hysteria2)
- Web control panel
- Automated deployment scripts
- Comprehensive security features
- Full documentation suite
