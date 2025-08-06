#!/bin/bash

# K3S Cleanup Script
# This script removes K3S, ArgoCD, and related components

set -e

# Check if gum is installed, install if not
check_gum() {
    if ! command -v gum &> /dev/null; then
        echo "Installing gum for better UI..."
        if command -v apt-get &> /dev/null; then
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
            echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
            sudo apt update -qq && sudo apt install -y gum
        elif command -v brew &> /dev/null; then
            brew install charmbracelet/tap/gum
        else
            echo "Please install gum manually: https://github.com/charmbracelet/gum#installation"
            exit 1
        fi
    fi
}

# Initialize gum
check_gum

print_status() {
    gum log --level info "$1"
}

print_success() {
    gum log --level success "$1"
}

print_warning() {
    gum log --level warn "$1"
}

print_error() {
    gum log --level error "$1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "This script should not be run as root"
        exit 1
    fi
}

# Function to prompt for confirmation
confirm_action() {
    local message="$1"
    echo -n "$message (y/N): "
    read -r response
    case $response in
        [Yy]* ) return 0;;
        * ) return 1;;
    esac
}

# Function to check if K3S is installed
check_k3s_installed() {
    command -v k3s &> /dev/null || [ -f /usr/local/bin/k3s ]
}

# Function to check if ArgoCD is installed
check_argocd_installed() {
    kubectl get namespace argocd &>/dev/null 2>&1
}

# Function to check if Helm is installed
check_helm_installed() {
    command -v helm &> /dev/null
}

# Function to check if K9s is installed
check_k9s_installed() {
    command -v k9s &> /dev/null
}

# Function to cleanup ArgoCD
cleanup_argocd() {
    print_status "Cleaning up ArgoCD..."
    
    if check_argocd_installed; then
        print_status "Removing ArgoCD applications..."
        kubectl delete applications --all -n argocd --ignore-not-found=true || true
        
        print_status "Uninstalling ArgoCD..."
        helm uninstall argocd -n argocd --ignore-not-found=true || true
        
        print_status "Removing ArgoCD namespace..."
        kubectl delete namespace argocd --ignore-not-found=true || true
        
        print_success "ArgoCD cleanup completed"
    else
        print_warning "ArgoCD not found, skipping cleanup"
    fi
}

# Function to cleanup K3S
cleanup_k3s() {
    print_status "Cleaning up K3S..."
    
    if check_k3s_installed; then
        print_status "Stopping K3S service..."
        sudo systemctl stop k3s || true
        
        print_status "Disabling K3S service..."
        sudo systemctl disable k3s || true
        
        print_status "Removing K3S service file..."
        sudo rm -f /etc/systemd/system/k3s.service || true
        
        sudo systemctl daemon-reload || true
        
        print_status "Removing K3S binary..."
        sudo rm -f /usr/local/bin/k3s || true
        
        print_status "Removing K3S data directory..."
        sudo rm -rf /var/lib/rancher/k3s || true
        
        print_status "Removing K3S configuration..."
        sudo rm -rf /etc/rancher/k3s || true
        
        print_success "K3S cleanup completed"
    else
        print_warning "K3S not found, skipping cleanup"
    fi
}

# Function to cleanup Helm
cleanup_helm() {
    print_status "Cleaning up Helm..."
    
    if check_helm_installed; then
        print_status "Removing Helm..."
        sudo rm -f /usr/local/bin/helm || true
        
        print_status "Removing Helm cache..."
        rm -rf ~/.cache/helm || true
        rm -rf ~/.config/helm || true
        
        print_success "Helm cleanup completed"
    else
        print_warning "Helm not found, skipping cleanup"
    fi
}

# Function to cleanup K9s
cleanup_k9s() {
    print_status "Cleaning up K9s..."
    
    if check_k9s_installed; then
        print_status "Removing K9s..."
        sudo apt remove -y k9s || true
        sudo apt autoremove -y || true
        
        print_success "K9s cleanup completed"
    else
        print_warning "K9s not found, skipping cleanup"
    fi
}

# Function to cleanup firewall rules
cleanup_firewall() {
    print_status "Cleaning up firewall rules..."
    
    if command -v ufw &> /dev/null; then
        print_status "Removing K3S firewall rules..."
        sudo ufw delete allow 6443/tcp || true
        sudo ufw delete allow 2379/tcp || true
        sudo ufw delete allow 2380/tcp || true
        sudo ufw delete allow 30080/tcp || true
        
        print_status "Removing HTTP firewall rule..."
        sudo ufw delete allow from any to any port 80 proto tcp || true
        
        print_success "Firewall cleanup completed"
    else
        print_warning "UFW not found, skipping firewall cleanup"
    fi
}

# Function to cleanup user files
cleanup_user_files() {
    print_status "Cleaning up user files..."
    
    USER_HOME=$(eval echo ~$USER)
    if [ -f "$USER_HOME/kubeconfig.yaml" ]; then
        print_status "Removing kubeconfig..."
        rm -f "$USER_HOME/kubeconfig.yaml"
    fi
    
    print_status "Removing shell profile entries..."
    sed -i '/export KUBECONFIG=\/etc\/rancher\/k3s\/k3s.yaml/d' ~/.bashrc || true
    sed -i '/export KUBECONFIG=\/etc\/rancher\/k3s\/k3s.yaml/d' ~/.profile || true
    
    print_status "Removing downloaded files..."
    rm -f k9s_linux_amd64.deb || true
    rm -f k3s-setup.sh || true
    rm -f network-setup.sh || true
    
    print_status "Removing configuration files..."
    rm -f k3s-config-*.env || true
    
    print_success "User files cleanup completed"
}

# Function to cleanup containers and images
cleanup_containers() {
    print_status "Cleaning up containers and images..."
    
    if command -v ctr &> /dev/null; then
        print_status "Removing containerd containers..."
        sudo ctr containers list | awk 'NR>1 {print $1}' | xargs -r sudo ctr containers rm || true
        sudo ctr images list | awk 'NR>1 {print $1}' | xargs -r sudo ctr images rm || true
    fi
    
    if command -v docker &> /dev/null; then
        print_status "Cleaning up Docker..."
        docker system prune -af || true
    fi
    
    print_success "Container cleanup completed"
}

# Function to show installation status
show_status() {
    print_status "Checking installation status..."
    echo
    
    echo "=== Component Status ==="
    if check_k3s_installed; then
        echo "K3S: ✅ Installed"
    else
        echo "K3S: ❌ Not installed"
    fi
    
    if check_argocd_installed; then
        echo "ArgoCD: ✅ Installed"
    else
        echo "ArgoCD: ❌ Not installed"
    fi
    
    if check_helm_installed; then
        echo "Helm: ✅ Installed"
    else
        echo "Helm: ❌ Not installed"
    fi
    
    if check_k9s_installed; then
        echo "K9s: ✅ Installed"
    else
        echo "K9s: ❌ Not installed"
    fi
    
    echo
}

# Function to resume installation
resume_installation() {
    print_status "Resuming K3S installation..."
    
    # Check current status
    show_status
    
    # Determine where to resume from
    if ! check_k3s_installed; then
        print_status "K3S not found, starting from beginning..."
        echo "Run: ./k3s-setup.sh"
        return
    fi
    
    if ! check_helm_installed; then
        print_status "Helm not found, resuming from Helm installation..."
        echo "Run: ./k3s-setup.sh (it will skip K3S installation)"
        return
    fi
    
    if ! check_argocd_installed; then
        print_status "ArgoCD not found, resuming from ArgoCD installation..."
        echo "Run: ./k3s-setup.sh (it will skip K3S and Helm installation)"
        return
    fi
    
    print_success "All components appear to be installed. Check ArgoCD applications."
}

# Function to perform full cleanup
full_cleanup() {
    print_warning "This will remove ALL K3S components and data!"
    print_warning "This action cannot be undone!"
    
    if ! confirm_action "Are you sure you want to proceed with full cleanup?"; then
        print_status "Cleanup cancelled"
        exit 0
    fi
    
    print_status "Starting full cleanup..."
    
    # Cleanup in reverse order of installation
    cleanup_argocd
    cleanup_k9s
    cleanup_helm
    cleanup_k3s
    cleanup_containers
    cleanup_firewall
    cleanup_user_files
    
    print_success "Full cleanup completed!"
    echo
    echo "To reinstall, run: ./k3s-setup.sh"
}

# Function to perform partial cleanup
partial_cleanup() {
    print_status "Partial cleanup options:"
    echo "1. Cleanup ArgoCD only"
    echo "2. Cleanup K3S only"
    echo "3. Cleanup Helm only"
    echo "4. Cleanup K9s only"
    echo "5. Cleanup user files only"
    echo "6. Cleanup firewall rules only"
    echo "7. Cleanup containers only"
    echo "8. Back to main menu"
    
    echo -n "Select option (1-8): "
    read -r choice
    
    case $choice in
        1) cleanup_argocd ;;
        2) cleanup_k3s ;;
        3) cleanup_helm ;;
        4) cleanup_k9s ;;
        5) cleanup_user_files ;;
        6) cleanup_firewall ;;
        7) cleanup_containers ;;
        8) return ;;
        *) print_error "Invalid option" ;;
    esac
}

# Main menu
main_menu() {
    while true; do
        echo
        echo "=========================================="
        echo "           K3S Cleanup Script"
        echo "=========================================="
        echo
        show_status
        echo "Options:"
        echo "1. Show installation status"
        echo "2. Resume installation"
        echo "3. Partial cleanup"
        echo "4. Full cleanup (removes everything)"
        echo "5. Exit"
        echo
        
        echo -n "Select option (1-5): "
        read -r choice
        
        case $choice in
            1) show_status ;;
            2) resume_installation ;;
            3) partial_cleanup ;;
            4) full_cleanup ;;
            5) print_status "Exiting..."; exit 0 ;;
            *) print_error "Invalid option" ;;
        esac
        
        echo
        echo "Press Enter to continue..."
        read -r
    done
}

# Command line options
case "${1:-}" in
    --status)
        show_status
        ;;
    --resume)
        resume_installation
        ;;
    --cleanup-argocd)
        cleanup_argocd
        ;;
    --cleanup-k3s)
        cleanup_k3s
        ;;
    --cleanup-helm)
        cleanup_helm
        ;;
    --cleanup-k9s)
        cleanup_k9s
        ;;
    --cleanup-all)
        full_cleanup
        ;;
    --help|-h)
        echo "Usage: $0 [OPTION]"
        echo
        echo "Options:"
        echo "  --status              Show installation status"
        echo "  --resume              Resume installation from current state"
        echo "  --cleanup-argocd      Remove ArgoCD only"
        echo "  --cleanup-k3s         Remove K3S only"
        echo "  --cleanup-helm        Remove Helm only"
        echo "  --cleanup-k9s         Remove K9s only"
        echo "  --cleanup-all         Remove all components (full cleanup)"
        echo "  --help, -h            Show this help message"
        echo
        echo "If no option is provided, interactive menu will be shown."
        ;;
    "")
        main_menu
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac 