#!/bin/bash

# SOLO Mode Reinstall Script
# This script will cleanly uninstall and reinstall SOLO mode

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    print_error "Please run this script as root or with sudo"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         XUI-SOLO Mode Clean Reinstall Script              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Backup existing .env files if they exist
BACKUP_DIR="/tmp/xray-cluster-backup-$(date +%s)"
if [ -d "/opt/xray-cluster" ]; then
    print_info "Backing up configuration files..."
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "/opt/xray-cluster/master/.env" ]; then
        cp /opt/xray-cluster/master/.env "$BACKUP_DIR/master.env"
        print_success "Backed up master .env"
    fi
    
    if [ -f "/opt/xray-cluster/node/.env" ]; then
        cp /opt/xray-cluster/node/.env "$BACKUP_DIR/node.env"
        print_success "Backed up node .env"
    fi
    
    print_success "Backup saved to: $BACKUP_DIR"
fi

# Stop and remove existing installation
print_info "Stopping existing services..."

if [ -d "/opt/xray-cluster/master" ]; then
    cd /opt/xray-cluster/master
    docker-compose down -v 2>/dev/null || true
    print_success "Master services stopped"
fi

if [ -d "/opt/xray-cluster/node" ]; then
    cd /opt/xray-cluster/node
    docker-compose down -v 2>/dev/null || true
    print_success "Node services stopped"
fi

# Remove Docker network
print_info "Removing Docker network..."
docker network rm xray-net 2>/dev/null || true

# Remove installation directory
print_info "Removing installation directory..."
rm -rf /opt/xray-cluster
print_success "Old installation removed"

echo ""
print_warning "Old installation has been completely removed."
echo ""

# Check if backup exists
if [ -d "$BACKUP_DIR" ]; then
    echo "Your configuration backup is at: $BACKUP_DIR"
    echo ""
    read -p "Do you want to use the backed up configuration? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        USE_BACKUP=true
        
        # Extract values from backup
        if [ -f "$BACKUP_DIR/master.env" ]; then
            PANEL_DOMAIN=$(grep "^PANEL_DOMAIN=" "$BACKUP_DIR/master.env" | cut -d'=' -f2)
            ADMIN_PASSWORD=$(grep "^ADMIN_PASSWORD=" "$BACKUP_DIR/master.env" | cut -d'=' -f2)
            CLUSTER_SECRET=$(grep "^CLUSTER_SECRET=" "$BACKUP_DIR/master.env" | cut -d'=' -f2)
        fi
        
        if [ -f "$BACKUP_DIR/node.env" ]; then
            NODE_DOMAIN=$(grep "^NODE_DOMAIN=" "$BACKUP_DIR/node.env" | cut -d'=' -f2)
            NODE_UUID=$(grep "^NODE_UUID=" "$BACKUP_DIR/node.env" | cut -d'=' -f2)
        fi
        
        print_success "Configuration loaded from backup"
    else
        USE_BACKUP=false
    fi
else
    USE_BACKUP=false
fi

# Get installation parameters
echo ""
print_info "Please provide installation parameters:"
echo ""

if [ "$USE_BACKUP" = false ] || [ -z "$PANEL_DOMAIN" ]; then
    read -p "Panel Domain (e.g., panel.example.com): " PANEL_DOMAIN
fi

if [ "$USE_BACKUP" = false ] || [ -z "$NODE_DOMAIN" ]; then
    read -p "Node Domain (e.g., node.example.com): " NODE_DOMAIN
fi

if [ "$USE_BACKUP" = false ] || [ -z "$ADMIN_PASSWORD" ]; then
    read -sp "Admin Password: " ADMIN_PASSWORD
    echo ""
fi

# Validate inputs
if [ -z "$PANEL_DOMAIN" ] || [ -z "$NODE_DOMAIN" ] || [ -z "$ADMIN_PASSWORD" ]; then
    print_error "All fields are required!"
    exit 1
fi

echo ""
print_info "Installation Summary:"
echo "  Panel Domain: $PANEL_DOMAIN"
echo "  Node Domain:  $NODE_DOMAIN"
echo "  Admin User:   admin"
echo ""

read -p "Proceed with installation? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Installation cancelled"
    exit 0
fi

# Run the installation
print_info "Starting SOLO mode installation..."
echo ""

bash install.sh --solo --panel-domain "$PANEL_DOMAIN" --node-domain "$NODE_DOMAIN" --admin-password "$ADMIN_PASSWORD"

# Check if installation was successful
if [ $? -eq 0 ]; then
    echo ""
    print_success "╔════════════════════════════════════════════════════════════╗"
    print_success "║         Installation Completed Successfully!              ║"
    print_success "╚════════════════════════════════════════════════════════════╝"
    echo ""
    print_info "Access your panel at: https://$PANEL_DOMAIN"
    print_info "Username: admin"
    print_info "Password: [your password]"
    echo ""
    print_info "Checking service status..."
    sleep 3
    docker ps --filter "name=xray-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    print_info "To view logs:"
    echo "  docker logs xray-master-web"
    echo "  docker logs xray-master-caddy"
    echo "  docker logs xray-node-xray"
    echo ""
    
    if [ -d "$BACKUP_DIR" ]; then
        print_info "Your backup is still available at: $BACKUP_DIR"
        print_warning "You can safely delete it once you verify everything works"
    fi
else
    print_error "Installation failed! Check the logs above for details."
    if [ -d "$BACKUP_DIR" ]; then
        print_info "Your backup is still available at: $BACKUP_DIR"
    fi
    exit 1
fi
