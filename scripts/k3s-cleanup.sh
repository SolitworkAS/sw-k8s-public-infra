#!/bin/bash

# K3S Cleanup Script
# This script removes everything installed by the K3S setup script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to prompt for confirmation
confirm_cleanup() {
    echo "=========================================="
    echo "           K3S Cleanup Script"
    echo "=========================================="
    echo
    print_warning "This script will remove:"
    echo "  - K3S cluster and all data"
    echo "  - ArgoCD and all applications"
    echo "  - Helm installations"
    echo "  - K9s"
    echo "  - All Kubernetes namespaces created"
    echo "  - All configuration files"
    echo
    print_warning "This action is IRREVERSIBLE!"
    echo
    
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ $confirm != "yes" ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
}

# Function to stop and remove K3S
cleanup_k3s() {
    print_status "Stopping and removing K3S..."
    
    # Stop K3S service
    sudo systemctl stop k3s || true
    
    # Remove K3S binary and data
    sudo /usr/local/bin/k3s-uninstall.sh || true
    
    # Remove K3S data directories
    sudo rm -rf /var/lib/rancher/k3s || true
    sudo rm -rf /etc/rancher/k3s || true
    sudo rm -rf /var/lib/kubelet || true
    
    # Remove K3S configuration files
    sudo rm -f /etc/systemd/system/k3s.service || true
    sudo rm -f /etc/systemd/system/k3s-agent.service || true
    
    # Reload systemd
    sudo systemctl daemon-reload || true
    
    print_success "K3S removed successfully"
}

# Function to remove Helm
cleanup_helm() {
    print_status "Removing Helm..."
    
    # Remove Helm binary
    sudo rm -f /usr/local/bin/helm || true
    
    # Remove Helm cache and config
    rm -rf ~/.helm || true
    rm -rf ~/.cache/helm || true
    
    print_success "Helm removed successfully"
}

# Function to remove K9s
cleanup_k9s() {
    print_status "Removing K9s..."
    
    # Remove K9s package
    sudo apt remove -y k9s || true
    sudo apt autoremove -y || true
    
    # Remove K9s configuration
    rm -rf ~/.k9s || true
    
    print_success "K9s removed successfully"
}

# Function to remove ArgoCD and applications
cleanup_argocd() {
    print_status "Removing ArgoCD and applications..."
    
    # Export KUBECONFIG if it exists
    if [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    elif [ -f "/home/$USER/kubeconfig.yaml" ]; then
        export KUBECONFIG=/home/$USER/kubeconfig.yaml
    fi
    
    # Remove ArgoCD applications if kubectl is available
    if command -v kubectl &> /dev/null; then
        # Delete all ArgoCD applications
        kubectl delete applications --all -n argocd --ignore-not-found=true || true
        
        # Delete ArgoCD namespace and all resources
        kubectl delete namespace argocd --ignore-not-found=true || true
        
        # Delete customer namespaces (common ones)
        kubectl delete namespace environment --ignore-not-found=true || true
        kubectl delete namespace argo --ignore-not-found=true || true
        kubectl delete namespace da --ignore-not-found=true || true
        kubectl delete namespace fc --ignore-not-found=true || true
        
        # Try to delete customer namespace (if we know the name)
        if [ -n "$CUSTOMER" ]; then
            kubectl delete namespace "$CUSTOMER" --ignore-not-found=true || true
        fi
    fi
    
    print_success "ArgoCD and applications removed successfully"
}

# Function to remove firewall rules
cleanup_firewall() {
    print_status "Removing K3S firewall rules..."
    
    # Remove UFW rules for K3S
    sudo ufw delete allow 6443/tcp || true
    sudo ufw delete allow 2379/tcp || true
    sudo ufw delete allow 2380/tcp || true
    
    print_success "Firewall rules removed successfully"
}

# Function to remove configuration files
cleanup_config_files() {
    print_status "Removing configuration files..."
    
    # Remove kubeconfig files
    rm -f ~/kubeconfig.yaml || true
    rm -f ~/.kube/config || true
    
    # Remove shell profile additions
    if [ -f ~/.bashrc ]; then
        sed -i '/export KUBECONFIG=\/etc\/rancher\/k3s\/k3s.yaml/d' ~/.bashrc || true
        sed -i '/export KUBECONFIG=\/home\/.*\/kubeconfig.yaml/d' ~/.bashrc || true
    fi
    
    if [ -f ~/.profile ]; then
        sed -i '/export KUBECONFIG=\/etc\/rancher\/k3s\/k3s.yaml/d' ~/.profile || true
        sed -i '/export KUBECONFIG=\/home\/.*\/kubeconfig.yaml/d' ~/.profile || true
    fi
    
    print_success "Configuration files removed successfully"
}

# Function to remove system configurations
cleanup_system_config() {
    print_status "Removing system configurations..."
    
    # Remove sysctl configurations
    sudo rm -f /etc/sysctl.d/90-kubelet.conf || true
    
    # Remove any remaining K3S related files
    sudo rm -rf /var/lib/rancher || true
    sudo rm -rf /opt/k3s || true
    
    print_success "System configurations removed successfully"
}

# Function to prompt for customer name
get_customer_name() {
    echo
    read -p "Enter the customer name used during setup (or press Enter to skip): " CUSTOMER
    echo
}

# Main cleanup function
main() {
    # Confirm cleanup
    confirm_cleanup
    
    # Get customer name for namespace cleanup
    get_customer_name
    
    print_status "Starting cleanup process..."
    
    # Stop and remove ArgoCD first (if kubectl is available)
    cleanup_argocd
    
    # Remove K3S
    cleanup_k3s
    
    # Remove Helm
    cleanup_helm
    
    # Remove K9s
    cleanup_k9s
    
    # Remove firewall rules
    cleanup_firewall
    
    # Remove configuration files
    cleanup_config_files
    
    # Remove system configurations
    cleanup_system_config
    
    echo
    print_success "Cleanup completed successfully!"
    echo
    echo "The following have been removed:"
    echo "  ✓ K3S cluster and all data"
    echo "  ✓ ArgoCD and applications"
    echo "  ✓ Helm"
    echo "  ✓ K9s"
    echo "  ✓ Configuration files"
    echo "  ✓ Firewall rules"
    echo
    echo "You may need to reboot the system to ensure all changes take effect."
}

# Run main function
main "$@" 