#!/bin/bash

# K3S Setup Script
# This script automates the installation and configuration of K3S, ArgoCD, and related components
# Based on the Terraform configuration from k3s/main/k3s/main.tf

set -e  # Exit on any error

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

# Function to detect network configuration
detect_network_config() {
    print_status "Detecting network configuration..."
    
    # Try multiple methods to get the IP address
    local public_ip=""
    local private_ip=""
    local local_ip=""
    
    # Get local IP address
    if command -v ip &> /dev/null; then
        local_ip=$(ip route get 1.1.1.1 | awk '{print $7; exit}' 2>/dev/null || echo "")
    fi
    
    # Get private IP address
    if [ -z "$local_ip" ]; then
        local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "")
    fi
    
    # Try to get public IP (with timeout and fallback)
    print_status "Attempting to detect public IP address..."
    
    # Method 1: ifconfig.me
    if command -v curl &> /dev/null; then
        public_ip=$(timeout 10 curl -s ifconfig.me 2>/dev/null || echo "")
    fi
    
    # Method 2: ipinfo.io
    if [ -z "$public_ip" ] && command -v curl &> /dev/null; then
        public_ip=$(timeout 10 curl -s ipinfo.io/ip 2>/dev/null || echo "")
    fi
    
    # Method 3: icanhazip.com
    if [ -z "$public_ip" ] && command -v curl &> /dev/null; then
        public_ip=$(timeout 10 curl -s icanhazip.com 2>/dev/null || echo "")
    fi
    
    # Method 4: checkip.amazonaws.com
    if [ -z "$public_ip" ] && command -v curl &> /dev/null; then
        public_ip=$(timeout 10 curl -s checkip.amazonaws.com 2>/dev/null || echo "")
    fi
    
    # If we can't get public IP, use local IP
    if [ -z "$public_ip" ]; then
        print_warning "Could not detect public IP address. Using local IP: $local_ip"
        public_ip="$local_ip"
    fi
    
    # Check if we're behind NAT or on a private network
    local is_private=false
    if [[ "$public_ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]]; then
        is_private=true
        print_warning "Detected private IP address: $public_ip"
        print_warning "This appears to be a private network. External access may be limited."
    fi
    
    # Store the detected IP
    DETECTED_IP="$public_ip"
    LOCAL_IP="$local_ip"
    IS_PRIVATE_NETWORK="$is_private"
    
    print_success "Network configuration detected:"
    echo "  Public/External IP: $DETECTED_IP"
    echo "  Local IP: $LOCAL_IP"
    echo "  Private Network: $IS_PRIVATE_NETWORK"
}

# Function to prompt for input with validation
prompt_input() {
    local prompt="$1"
    local validation_regex="$2"
    local error_message="$3"
    local default_value="$4"
    
    # Force output to be unbuffered
    echo -n "$prompt" >&2
    
    while true; do
        if [ -n "$default_value" ]; then
            echo -n " [$default_value]: " >&2
            read -r input
            input=${input:-$default_value}
        else
            echo -n ": " >&2
            read -r input
        fi
        
        if [ -z "$input" ]; then
            print_error "Input cannot be empty"
            continue
        fi
        
        if [ -n "$validation_regex" ]; then
            if [[ $input =~ $validation_regex ]]; then
                echo "$input"
                return 0
            else
                print_error "$error_message (input: '$input', regex: '$validation_regex')"
                continue
            fi
        else
            echo "$input"
            return 0
        fi
    done
}

# Function to prompt for boolean input
prompt_boolean() {
    local prompt="$1"
    local default_value="$2"
    
    while true; do
        if [ -n "$default_value" ]; then
            echo -n "$prompt (y/n) [$default_value]: " >&2
            read -r input
            input=${input:-$default_value}
        else
            echo -n "$prompt (y/n): " >&2
            read -r input
        fi
        
        case $input in
            [Yy]* ) echo "true"; return 0;;
            [Nn]* ) echo "false"; return 0;;
            * ) print_error "Please answer yes or no";;
        esac
    done
}

# Function to generate random strings
generate_random_string() {
    local length=$1
    cat /dev/urandom | tr -dc 'a-z0-9' | fold -w $length | head -n 1
}

generate_random_password() {
    local length=$1
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "This script should not be run as root"
        exit 1
    fi
}

# Function to check if K3S is installed
check_k3s_installed() {
    if command -v k3s &> /dev/null || [ -f /usr/local/bin/k3s ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if ArgoCD is installed
check_argocd_installed() {
    if kubectl get namespace argocd &>/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check if Helm is installed
check_helm_installed() {
    if command -v helm &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if K9s is installed
check_k9s_installed() {
    if command -v k9s &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to show installation status
show_installation_status() {
    print_status "Checking current installation status..."
    echo
    
    echo "=== Component Status ==="
    if check_k3s_installed; then
        echo "K3S: ✅ Installed"
        K3S_INSTALLED=true
    else
        echo "K3S: ❌ Not installed"
        K3S_INSTALLED=false
    fi
    
    if check_helm_installed; then
        echo "Helm: ✅ Installed"
        HELM_INSTALLED=true
    else
        echo "Helm: ❌ Not installed"
        HELM_INSTALLED=false
    fi
    
    if check_argocd_installed; then
        echo "ArgoCD: ✅ Installed"
        ARGOCD_INSTALLED=true
    else
        echo "ArgoCD: ❌ Not installed"
        ARGOCD_INSTALLED=false
    fi
    
    if check_k9s_installed; then
        echo "K9s: ✅ Installed"
        K9S_INSTALLED=true
    else
        echo "K9s: ❌ Not installed"
        K9S_INSTALLED=false
    fi
    
    echo
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if running on Ubuntu/Debian
    if ! command -v apt-get &> /dev/null; then
        print_error "This script is designed for Ubuntu/Debian systems"
        exit 1
    fi
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        print_status "Installing curl..."
        sudo apt update
        sudo apt install -y curl
    fi
    
    # Check if wget is available
    if ! command -v wget &> /dev/null; then
        print_status "Installing wget..."
        sudo apt update
        sudo apt install -y wget
    fi
    
    # Check if timeout is available
    if ! command -v timeout &> /dev/null; then
        print_status "Installing coreutils (for timeout)..."
        sudo apt update
        sudo apt install -y coreutils
    fi
    
    # Check for common K3S startup issues
    print_status "Checking system requirements..."
    
    # Check if swap is enabled (K3S doesn't like swap)
    if swapon --show | grep -q .; then
        print_warning "Swap is enabled. K3S may have issues. Consider disabling swap."
        print_warning "To disable swap: sudo swapoff -a && sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"
    fi
    
    # Check available memory
    mem_total=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$mem_total" -lt 2048 ]; then
        print_warning "System has less than 2GB RAM. K3S may have issues."
    fi
    
    # Check available disk space
    disk_free=$(df / | awk 'NR==2{printf "%.0f", $4}')
    if [ "$disk_free" -lt 10240 ]; then
        print_warning "Less than 10GB free disk space. K3S may have issues."
    fi
    
    # Check if ports are available
    print_status "Checking port availability..."
    local ports=(6443 8080 80 443)
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Port $port is already in use. This may cause conflicts."
        fi
    done
    
    print_success "Prerequisites check completed"
}

# Function to collect user input
collect_user_input() {
    print_status "Collecting configuration parameters..."
    
    # Detect network configuration first
    detect_network_config
    
    # General variables
    CUSTOMER=$(prompt_input "Enter customer shorthand (lowercase letters and numbers only)" "^[a-z0-9]+$" "Customer must only contain lowercase letters and numbers")
    
    # Domain configuration
    if [ "$IS_PRIVATE_NETWORK" = "true" ]; then
        print_warning "Private network detected. Using nip.io for local development."
        DOMAIN=$(prompt_input "Enter domain for nip.io (e.g., myapp)" "" "" "myapp")
        DOMAIN="${DOMAIN}.${DETECTED_IP}.nip.io"
        print_status "Using nip.io domain: $DOMAIN"
    else
        DOMAIN=$(prompt_input "Enter domain (e.g., afcsoftware.com)" "" "" "afcsoftware.com")
    fi
    
    SELF_HOSTED=$(prompt_boolean "Is this self-hosted?" "true")
    
    # Container registry variables
    CONTAINER_REGISTRY=$(prompt_input "Enter container registry URL" "" "" "imagesdevregistry.azurecr.io")
    CONTAINER_REGISTRY_USERNAME=$(prompt_input "Enter container registry username" "^.+$" "Username cannot be empty")
    CONTAINER_REGISTRY_PASSWORD=$(prompt_input "Enter container registry password" "^.+$" "Password cannot be empty")
    
    # Application admin variables
    APP_ADMIN_EMAIL=$(prompt_input "Enter application admin email" "^[^@]+@[^@]+\.[^@]+$" "Must be a valid email address")
    APP_ADMIN_FIRST_NAME=$(prompt_input "Enter application admin first name" "^.+$" "First name cannot be empty")
    APP_ADMIN_LAST_NAME=$(prompt_input "Enter application admin last name" "^.+$" "Last name cannot be empty")
    
    # K3S variables
    K3S_TOKEN=$(prompt_input "Enter K3S token (or 'null' for auto-generation)" "" "" "null")
    if [ "$K3S_TOKEN" = "null" ]; then
        K3S_TOKEN=$(generate_random_string 32)
        print_status "Generated K3S token: $K3S_TOKEN"
    fi
    
    # Deployment options
    DEPLOYMENT_REVISION=$(prompt_input "Enter deployment revision" "" "" "HEAD")
    DEPLOY_DA_APP=$(prompt_boolean "Deploy DA app?" "false")
    DEPLOY_FC_APP=$(prompt_boolean "Deploy FC app?" "false")
    
    # OAuth/SSO variables
    GITHUB_CLIENT_ID=$(prompt_input "Enter GitHub client ID (or 'null')" "" "" "null")
    GITHUB_CLIENT_SECRET=$(prompt_input "Enter GitHub client secret (or 'null')" "" "" "null")
    
    SSO_ISSUER=$(prompt_input "Enter SSO issuer (or 'null')" "" "" "null")
    SSO_CLIENT_ID=$(prompt_input "Enter SSO client ID (or 'null')" "" "" "null")
    SSO_CLIENT_SECRET=$(prompt_input "Enter SSO client secret (or 'null')" "" "" "null")
    
    MICROSOFT_CLIENT_ID=$(prompt_input "Enter Microsoft client ID (or 'null')" "" "" "null")
    MICROSOFT_CLIENT_SECRET=$(prompt_input "Enter Microsoft client secret (or 'null')" "" "" "null")
    
    INTUIT_CLIENT_ID=$(prompt_input "Enter Intuit client ID (or 'null')" "" "" "null")
    INTUIT_CLIENT_SECRET=$(prompt_input "Enter Intuit client secret (or 'null')" "" "" "null")
    INTUIT_REDIRECT_URI=$(prompt_input "Enter Intuit redirect URI (or 'null')" "" "" "null")
    
    ENCRYPTION_KEY=$(prompt_input "Enter encryption key (or 'null')" "" "" "null")
    
    # Generate random credentials
    print_status "Generating random credentials..."
    POSTGRES_DATABASE="u$(generate_random_string 8)"
    POSTGRES_USERNAME="u$(generate_random_string 8)"
    POSTGRES_PASSWORD="u$(generate_random_password 16)"
    BI_DEV_ROLE="u$(generate_random_string 8)"
    ARGOWORKFLOWS_USERNAME="u$(generate_random_string 8)"
    ARGOWORKFLOWS_PASSWORD="u$(generate_random_password 16)"
    FC_USER="u$(generate_random_string 8)"
    FC_PASSWORD="u$(generate_random_password 16)"
    FC_DATABASE="u$(generate_random_string 8)"
    MINIO_ROOT_USER=$(generate_random_string 8)
    MINIO_ROOT_PASSWORD=$(generate_random_password 16)
    
    print_success "Configuration parameters collected"
}

# Function to install K3S
install_k3s() {
    print_status "Installing K3S..."
    
    # Update system and install UFW
    sudo apt update
    sudo apt install -y ufw
    
    # Install K3S with proper configuration
    curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN sh -s - server --cluster-init --write-kubeconfig-mode 644 --bind-address 0.0.0.0 --advertise-address $LOCAL_IP
    
    # Wait for K3S to start
    print_status "Waiting for K3S to start..."
    sleep 30
    
    # Check if K3S is running
    if ! sudo systemctl is-active --quiet k3s; then
        print_error "K3S failed to start. Checking logs..."
        sudo journalctl -u k3s --no-pager -n 50
        print_error "K3S startup failed. Please check the logs above for details."
        
        # Additional diagnostics
        print_status "Additional diagnostics:"
        echo "System memory:"
        free -h
        echo
        echo "Disk space:"
        df -h
        echo
        echo "K3S service status:"
        sudo systemctl status k3s --no-pager
        echo
        print_error "K3S startup failed. Please check the logs and system resources above."
        exit 1
    fi
    
    # Wait for API to be ready
    print_status "Waiting for K3S API to be ready..."
    timeout=120
    counter=0
    while [ $counter -lt $timeout ]; do
        if kubectl get nodes &>/dev/null; then
            break
        fi
        sleep 2
        counter=$((counter + 2))
        echo -n "."
    done
    echo
    
    if [ $counter -ge $timeout ]; then
        print_error "K3S API failed to become ready within $timeout seconds"
        sudo journalctl -u k3s --no-pager -n 20
        exit 1
    fi
    
    # Configure firewall
    sudo ufw allow 6443/tcp
    sudo ufw allow 2379/tcp
    sudo ufw allow 2380/tcp
    sudo ufw allow 8080/tcp  # ArgoCD UI
    sudo ufw allow 80/tcp    # HTTP
    sudo ufw allow 443/tcp   # HTTPS
    sudo ufw reload
    
    print_success "K3S installed and running successfully"
}

# Function to install Helm
install_helm() {
    print_status "Installing Helm..."
    
    # Install Helm
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    
    # Verify installation
    helm version
    
    print_success "Helm installed successfully"
}

# Function to install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    # Verify K3S is still running
    if ! kubectl get nodes &>/dev/null; then
        print_error "K3S is not responding. Checking status..."
        sudo systemctl status k3s
        exit 1
    fi
    
    # Create namespace
    kubectl create namespace argocd || true
    
    # Add ArgoCD Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Install ArgoCD with NodePort for external access
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --set server.metrics.enabled=true \
        --set controller.metrics.enabled=true \
        --set repoServer.metrics.enabled=true \
        --set applicationSet.metrics.enabled=true \
        --set server.service.type=NodePort \
        --set server.service.nodePort=30080
    
    # Wait for ArgoCD to be ready
    print_status "Waiting for ArgoCD to be ready..."
    sleep 60
    
    print_success "ArgoCD installed successfully"
}

# Function to install K9s
install_k9s() {
    print_status "Installing K9s..."
    
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    
    # Download and install K9s
    wget https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_linux_amd64.deb
    sudo apt install -y ./k9s_linux_amd64.deb
    rm k9s_linux_amd64.deb
    
    # Configure KUBECONFIG in shell profiles
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.profile
    source ~/.bashrc
    source ~/.profile
    
    # Ensure kubeconfig is readable and copy to user's home directory
    USER_HOME=$(eval echo ~$USER)
    sudo cp /etc/rancher/k3s/k3s.yaml "$USER_HOME/kubeconfig.yaml"
    sudo chown $USER:$USER "$USER_HOME/kubeconfig.yaml"
    sudo chmod 600 "$USER_HOME/kubeconfig.yaml"
    
    print_success "K9s installed successfully"
}

# Function to login to Helm registry
helm_login() {
    print_status "Logging into Helm registry..."
    
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    helm registry login $CONTAINER_REGISTRY -u $CONTAINER_REGISTRY_USERNAME -p $CONTAINER_REGISTRY_PASSWORD
    
    print_success "Helm registry login completed"
}

# Function to configure ArgoCD repositories
configure_argocd_repositories() {
    print_status "Configuring ArgoCD repositories..."
    
    # Public chart repository
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: sw-public-chart
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: https://github.com/SolitworkAS/sw-k8s-public-infra.git
  project: default
  insecure: "true"
EOF
    
    # Private chart repository
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: sw-private-chart
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: "$CONTAINER_REGISTRY/charts"
  name: "sw-private-chart"
  type: "helm"
  enableOCI: "true"
  username: "$CONTAINER_REGISTRY_USERNAME"
  password: "$CONTAINER_REGISTRY_PASSWORD"
  project: "default"
EOF
    
    print_success "ArgoCD repositories configured"
}

# Function to deploy ArgoCD application
deploy_argocd_application() {
    print_status "Deploying ArgoCD application..."
    
    # Create ArgoCD application
    kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: initial-$CUSTOMER-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: "https://github.com/SolitworkAS/sw-k8s-public-infra"
    targetRevision: "$DEPLOYMENT_REVISION"
    path: "sw-public-chart"
    helm:
      values: |
        global:
          selfhosted: "$CUSTOMER"
          domain: "$DOMAIN"
          publicIp: "$DETECTED_IP"
          container:
            registry: "$CONTAINER_REGISTRY"
            username: "$CONTAINER_REGISTRY_USERNAME"
            password: "$CONTAINER_REGISTRY_PASSWORD"
            imagePullSecret: "registry-secret"
          deployDaChart: "$DEPLOY_DA_APP"
          deployFinancialChart: "$DEPLOY_FC_APP"
          intuit:
            clientId: "$INTUIT_CLIENT_ID"
            clientSecret: "$INTUIT_CLIENT_SECRET"
            redirectUri: "$INTUIT_REDIRECT_URI"
            encryptionKey: "$ENCRYPTION_KEY"
        sw-private-chart:
          environment-chart:
            dex:
              connectors:
                github:
                  clientID: "$GITHUB_CLIENT_ID"
                  clientSecret: "$GITHUB_CLIENT_SECRET"
                solitwork:
                  clientID: "$SSO_CLIENT_ID"
                  clientSecret: "$SSO_CLIENT_SECRET"
                  issuer: "$SSO_ISSUER"
                microsoft:
                  clientID: "$MICROSOFT_CLIENT_ID"
                  clientSecret: "$MICROSOFT_CLIENT_SECRET"
            namespace: "environment"
            domain: "$DOMAIN"
            minio:
              bucket:
                name: "argo-workflows"
            argo-workflows:
              namespaceOverride: "argo"
              server:
                service:
                  type: NodePort
              postgres:
                username: "$ARGOWORKFLOWS_USERNAME"
                password: "$ARGOWORKFLOWS_PASSWORD"
          customer-chart:
            namespace: "$CUSTOMER"
            appAdmin:
              email: "$APP_ADMIN_EMAIL"
              firstName: "$APP_ADMIN_FIRST_NAME"
              lastName: "$APP_ADMIN_LAST_NAME"
            postgres:
              database: "$POSTGRES_DATABASE"
              username: "$POSTGRES_USERNAME"
              password: "$POSTGRES_PASSWORD"
              biDevRole: "$BI_DEV_ROLE"
              fcUser: "$FC_USER"
              fcPassword: "$FC_PASSWORD"
              fcDatabase: "$FC_DATABASE"
            minio:
              rootUser: "$MINIO_ROOT_USER"
              rootPassword: "$MINIO_ROOT_PASSWORD"
            fc:
              enabled: "$DEPLOY_FC_APP"
            da:
              enabled: "$DEPLOY_DA_APP"
          da-chart:
            namespace: "da"
            da:
              da_frontend_image: "images/da-service/da-frontend"
              da_service_image: "images/da-service/da-service"
          financial-chart:
            namespace: "fc"
            fc:
              fc_frontend_image: "images/financial-close-service/financial-close-frontend"
              fc_service_image: "images/financial-close-service/financial-close-backend"
  destination:
    server: "https://kubernetes.default.svc"
    namespace: "$CUSTOMER"
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
    - ServerSideApply=true
EOF
    
    # Trigger ArgoCD refresh
    echo "Triggering ArgoCD refresh..."
    kubectl patch application initial-$CUSTOMER-app -n argocd \
        -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}' \
        --type merge || echo "Failed to patch ArgoCD app for refresh, continuing anyway"
    
    print_success "ArgoCD application deployed"
}

# Function to display final information
display_final_info() {
    print_success "K3S setup completed successfully!"
    echo
    echo "=== Configuration Summary ==="
    echo "Customer: $CUSTOMER"
    echo "Domain: $DOMAIN"
    echo "K3S Token: $K3S_TOKEN"
    echo "Detected IP: $DETECTED_IP"
    echo "Local IP: $LOCAL_IP"
    echo "Private Network: $IS_PRIVATE_NETWORK"
    echo
    echo "=== Generated Credentials ==="
    echo "Postgres Database: $POSTGRES_DATABASE"
    echo "Postgres Username: $POSTGRES_USERNAME"
    echo "Postgres Password: $POSTGRES_PASSWORD"
    echo "MinIO Root User: $MINIO_ROOT_USER"
    echo "MinIO Root Password: $MINIO_ROOT_PASSWORD"
    echo
    echo "=== Access Information ==="
    USER_HOME=$(eval echo ~$USER)
    echo "Kubeconfig location: $USER_HOME/kubeconfig.yaml"
    echo "ArgoCD UI: http://$DETECTED_IP:30080"
    if [ "$IS_PRIVATE_NETWORK" = "true" ]; then
        echo "Local ArgoCD UI: http://$LOCAL_IP:30080"
    fi
    echo
    echo "=== Next Steps ==="
    echo "1. Access ArgoCD UI to monitor deployments"
    echo "2. Use 'kubectl get pods -A' to check pod status"
    echo "3. Use 'k9s' for cluster management"
    echo "4. Export KUBECONFIG: export KUBECONFIG=$USER_HOME/kubeconfig.yaml"
    echo
    if [ "$IS_PRIVATE_NETWORK" = "true" ]; then
        echo "=== Private Network Notes ==="
        echo "You are running on a private network. External access may be limited."
        echo "Consider setting up port forwarding or VPN for external access."
        echo "The nip.io domain ($DOMAIN) will resolve to your local IP for testing."
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "           K3S Setup Script"
    echo "=========================================="
    echo
    
    # Check if running as root
    check_root
    
    # Check prerequisites
    check_prerequisites
    
    # Check if running from pipe and provide alternative
    if [ ! -t 0 ]; then
        echo "Detected pipe execution. For better experience, download and run the script directly:"
        echo "curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/Script/scripts/k3s-setup.sh -o k3s-setup.sh"
        echo "chmod +x k3s-setup.sh"
        echo "./k3s-setup.sh"
        echo ""
        echo "Continuing with pipe execution..."
        echo ""
    fi
    
    # Show current installation status
    show_installation_status
    
    # Check if components are already installed and offer resume options
    if [ "$K3S_INSTALLED" = "true" ] || [ "$HELM_INSTALLED" = "true" ] || [ "$ARGOCD_INSTALLED" = "true" ] || [ "$K9S_INSTALLED" = "true" ]; then
        print_warning "Some components are already installed!"
        echo
        echo "Options:"
        echo "1. Continue with installation (skip existing components)"
        echo "2. Clean up and start fresh"
        echo "3. Exit"
        echo
        echo -n "Select option (1-3): "
        read -r choice
        
        case $choice in
            1)
                print_status "Continuing with installation, skipping existing components..."
                ;;
            2)
                print_status "Cleaning up existing installation..."
                if [ -f "./k3s-cleanup.sh" ]; then
                    ./k3s-cleanup.sh --cleanup-all
                else
                    print_warning "Cleanup script not found. Please run cleanup manually."
                    exit 1
                fi
                ;;
            3)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option, exiting..."
                exit 1
                ;;
        esac
    fi
    
    # Collect user input
    collect_user_input
    
    # Install and configure components (skip if already installed)
    if [ "$K3S_INSTALLED" != "true" ]; then
        install_k3s
    else
        print_status "K3S already installed, skipping..."
    fi
    
    if [ "$HELM_INSTALLED" != "true" ]; then
        install_helm
    else
        print_status "Helm already installed, skipping..."
    fi
    
    if [ "$ARGOCD_INSTALLED" != "true" ]; then
        install_argocd
    else
        print_status "ArgoCD already installed, skipping..."
    fi
    
    if [ "$K9S_INSTALLED" != "true" ]; then
        install_k9s
    else
        print_status "K9s already installed, skipping..."
    fi
    
    helm_login
    configure_argocd_repositories
    deploy_argocd_application
    
    # Display final information
    display_final_info
}

# Run main function
main "$@" 