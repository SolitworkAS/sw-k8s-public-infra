#!/bin/bash

# Network Setup Script for K3S
# This script helps configure network settings for K3S deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
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

# Function to detect network interfaces
detect_interfaces() {
    print_status "Detecting network interfaces..."
    
    echo "Available network interfaces:"
    ip addr show | grep -E "^[0-9]+:" | awk '{print $2}' | sed 's/://'
    echo
    
    # Get default route interface
    local default_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$default_interface" ]; then
        echo "Default interface: $default_interface"
        echo "Default interface IP: $(ip addr show $default_interface | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"
    fi
    echo
}

# Function to check port availability
check_ports() {
    print_status "Checking port availability..."
    
    local ports=(6443 30080 80 443 8080 2379 2380)
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            local process=$(netstat -tulnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f2)
            print_warning "Port $port is in use by: $process"
        else
            print_success "Port $port is available"
        fi
    done
    echo
}

# Function to test external connectivity
test_connectivity() {
    print_status "Testing external connectivity..."
    
    local endpoints=(
        "https://ifconfig.me"
        "https://ipinfo.io"
        "https://icanhazip.com"
        "https://checkip.amazonaws.com"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s --max-time 10 "$endpoint" >/dev/null 2>&1; then
            print_success "Can reach $endpoint"
        else
            print_warning "Cannot reach $endpoint"
        fi
    done
    echo
}

# Function to configure firewall
configure_firewall() {
    print_status "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        print_status "UFW is available. Configuring rules..."
        
        # Allow SSH
        sudo ufw allow ssh
        
        # Allow K3S ports
        sudo ufw allow 6443/tcp
        sudo ufw allow 2379/tcp
        sudo ufw allow 2380/tcp
        
        # Allow ArgoCD and web ports
        sudo ufw allow 30080/tcp
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        
        # Add specific HTTP rule with priority 1002
        sudo ufw insert 2 allow from any to any port 80 proto tcp comment "HTTP access"
        
        # Enable UFW if not already enabled
        if ! sudo ufw status | grep -q "Status: active"; then
            print_warning "Enabling UFW firewall..."
            echo "y" | sudo ufw enable
        fi
        
        print_success "Firewall configured"
    else
        print_warning "UFW not available. Please install it: sudo apt install ufw"
    fi
    echo
}

# Function to setup port forwarding (for private networks)
setup_port_forwarding() {
    print_status "Port forwarding setup for private networks..."
    
    echo "If you're on a private network and need external access, you can:"
    echo "1. Use SSH port forwarding:"
    echo "   ssh -L 30080:localhost:30080 user@your-server"
    echo "2. Use ngrok (if available):"
    echo "   ngrok http 30080"
    echo "3. Configure your router's port forwarding"
    echo
}

# Function to test nip.io resolution
test_nip_io() {
    local ip=$1
    local test_domain="test.${ip}.nip.io"
    
    print_status "Testing nip.io resolution for IP: $ip"
    
    if nslookup "$test_domain" >/dev/null 2>&1; then
        print_success "nip.io resolution works for $test_domain"
    else
        print_warning "nip.io resolution failed for $test_domain"
        print_warning "This may affect local development with nip.io domains"
    fi
    echo
}

# Function to show network information
show_network_info() {
    print_status "Network Information Summary"
    echo "=================================="
    
    # Get IP addresses
    local public_ip=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "Unknown")
    local local_ip=$(hostname -I | awk '{print $1}')
    
    echo "Public IP: $public_ip"
    echo "Local IP: $local_ip"
    echo "Hostname: $(hostname)"
    echo "Domain: $(hostname -d 2>/dev/null || echo "None")"
    
    # Check if it's a private network
    if [[ "$public_ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]]; then
        echo "Network Type: Private"
        test_nip_io "$public_ip"
    else
        echo "Network Type: Public"
    fi
    
    echo
}

# Function to provide troubleshooting tips
troubleshooting_tips() {
    print_status "Troubleshooting Tips"
    echo "========================"
    echo
    echo "If K3S fails to start:"
    echo "1. Check system resources: free -h && df -h"
    echo "2. Check K3S logs: sudo journalctl -u k3s -f"
    echo "3. Check if ports are available: netstat -tuln | grep :6443"
    echo "4. Disable swap: sudo swapoff -a"
    echo
    echo "If ArgoCD is not accessible:"
    echo "1. Check if ArgoCD pods are running: kubectl get pods -n argocd"
    echo "2. Check ArgoCD service: kubectl get svc -n argocd"
    echo "3. Check firewall: sudo ufw status"
    echo "4. Try local access: curl http://localhost:30080"
    echo
    echo "If nip.io domains don't work:"
    echo "1. Check DNS resolution: nslookup test.127.0.0.1.nip.io"
    echo "2. Try using localhost or local IP directly"
    echo "3. Consider using /etc/hosts for local development"
    echo
}

# Main function
main() {
    echo "=========================================="
    echo "        K3S Network Setup Script"
    echo "=========================================="
    echo
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "This script should not be run as root"
        exit 1
    fi
    
    # Show network information
    show_network_info
    
    # Detect interfaces
    detect_interfaces
    
    # Check ports
    check_ports
    
    # Test connectivity
    test_connectivity
    
    # Configure firewall
    configure_firewall
    
    # Setup port forwarding info
    setup_port_forwarding
    
    # Show troubleshooting tips
    troubleshooting_tips
    
    print_success "Network setup check completed!"
    echo
    echo "Next steps:"
    echo "1. Run the main K3S setup script: ./k3s-setup.sh"
    echo "2. If you encounter issues, check the troubleshooting tips above"
    echo "3. For private networks, consider setting up port forwarding"
}

# Run main function
main "$@" 