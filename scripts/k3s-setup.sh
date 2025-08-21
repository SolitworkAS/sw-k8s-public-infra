#!/bin/bash

set -e

# =============================================================================
# K3S Setup Script - Lightweight Kubernetes with ArgoCD
# 
# This script installs and configures:
# - K3S (lightweight Kubernetes)
# - Helm (package manager)
# - ArgoCD (GitOps continuous deployment)
# - K9s (cluster management UI)
# 
# The script handles network detection, configuration management, and
# provides update capabilities for ArgoCD applications.
# =============================================================================

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Install gum for better UI if not present
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

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

configure_argocd_health_scripts() {
  print_status "Installing Argo CD health script for CloudNativePG Cluster..."
  # Nil-safe health.lua for postgresql.cnpg.io/Cluster
  kubectl patch configmap argocd-cm -n argocd --type merge -p "$(cat <<'JSON'
{
  "data": {
    "resource.customizations.health.postgresql.cnpg.io_Cluster": "hs = { status = \"Progressing\", message = \"\" }\n\nif obj.status ~= nil then\n  local phase = obj.status.phase\n  if phase == \"Healthy\" then\n    hs.status = \"Healthy\"\n  elseif phase == \"Failed\" then\n    hs.status = \"Degraded\"\n  else\n    hs.status = \"Progressing\"\n  end\n\n  if obj.status.phaseReason ~= nil then\n    hs.message = tostring(obj.status.phaseReason)\n  elseif obj.status.currentPrimary ~= nil then\n    hs.message = \"primary: \" .. tostring(obj.status.currentPrimary)\n  else\n    hs.message = \"phase: \" .. tostring(phase)\n  end\nelse\n  hs.status = \"Progressing\"\n  hs.message = \"Cluster status not yet available\"\nend\n\nreturn hs\n"
  }
}
JSON
)"
  # Argo CD components cache config; restart so the script is loaded
  kubectl rollout restart deploy/argocd-repo-server -n argocd || true
  kubectl rollout restart deploy/argocd-application-controller -n argocd || true
  print_success "Health script configured"
}

# =============================================================================
# CLI FLAG PARSING
# =============================================================================

# Defaults
SELF_HOSTED=true
CUSTOM_DOMAIN=""

parse_cli_flags() {
    local skip_next=false
    for arg in "$@"; do
        if [ "$skip_next" = true ]; then
            skip_next=false
            continue
        fi
        case "$arg" in
            --swdeployment)
                # Hosted (cloud) deployment
                SELF_HOSTED=false
                ;;
            --custom-domain)
                # Next argument must be the domain value
                skip_next=true
                ;;
            *)
                if [ "$skip_next" = true ] && [ -z "$CUSTOM_DOMAIN" ]; then
                    CUSTOM_DOMAIN="$arg"
                    skip_next=false
                fi
                ;;
        esac
    done
}

# Print functions for consistent UI
print_status() { gum log --level info "$1"; }
print_success() { gum style --foreground 10 "✅ $1"; }
print_warning() { gum log --level warn "$1"; }
print_error() { gum log --level error "$1"; }

# Generate random strings and passwords
generate_random_string() { cat /dev/urandom | tr -dc 'a-z0-9' | fold -w $1 | head -n 1; }
generate_random_password() { cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $1 | head -n 1; }

# =============================================================================
# NETWORK DETECTION
# =============================================================================

# Detect network configuration (public/private IP, local IP)
detect_network_config() {
    print_status "Detecting network configuration..."
    
    local public_ip=""
    local local_ip=""
    
    # Get local IP
    if command -v ip &> /dev/null; then
        local_ip=$(ip route get 1.1.1.1 | awk '{print $7; exit}' 2>/dev/null || echo "")
    fi
    if [ -z "$local_ip" ]; then
        local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "")
    fi
    
    # Get public IP from multiple sources
    if command -v curl &> /dev/null; then
        for endpoint in ifconfig.me ipinfo.io/ip icanhazip.com checkip.amazonaws.com; do
            public_ip=$(timeout 10 curl -s "$endpoint" 2>/dev/null || echo "")
            [ -n "$public_ip" ] && break
        done
    fi
    
    if [ -z "$public_ip" ]; then
        print_warning "Could not detect public IP address. Using local IP: $local_ip"
        public_ip="$local_ip"
    fi
    
    # Check if private network
    local is_private=false
    if [[ "$public_ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]]; then
        is_private=true
        print_warning "Detected private IP address: $public_ip"
    fi
    
    DETECTED_IP="$public_ip"
    LOCAL_IP="$local_ip"
    IS_PRIVATE_NETWORK="$is_private"
    
    print_success "Network configuration detected"
    echo "  Public/External IP: $DETECTED_IP"
    echo "  Local IP: $LOCAL_IP"
    echo "  Private Network: $IS_PRIVATE_NETWORK"
}

# =============================================================================
# USER INPUT FUNCTIONS
# =============================================================================

# Prompt for input with validation and default values
prompt_input() {
    local prompt="$1"
    local validation_regex="$2"
    local error_message="$3"
    local default_value="$4"
    
    while true; do
        if [ -n "$default_value" ]; then
            input=$(gum input --prompt "$prompt" --placeholder "$default_value")
        else
            input=$(gum input --prompt "$prompt")
        fi
        
        if [ -z "$input" ]; then
            print_error "Input cannot be empty. Try again."
            continue
        fi
        
        if [ -n "$validation_regex" ]; then
            if [[ "$input" =~ $validation_regex ]]; then
                echo "$input"
                return 0
            else
                print_error "Try again. Must comply with: $error_message"
                continue
            fi
        else
            echo "$input"
            return 0
        fi
    done
}

# Prompt for boolean values
prompt_boolean() {
    local prompt="$1"
    local default_value="$2"
    
    if [ -n "$default_value" ]; then
        if [ "$default_value" = "true" ]; then
            gum confirm "$prompt" --default=true && echo "true" || echo "false"
        else
            gum confirm "$prompt" --default=false && echo "true" || echo "false"
        fi
    else
        gum confirm "$prompt" && echo "true" || echo "false"
    fi
}

# Prompt for optional values (null if empty)
prompt_optional() {
    local prompt="$1"
    local default_value="$2"
    
    if [ -n "$default_value" ]; then
        input=$(gum input --prompt "$prompt" --placeholder "$default_value (press Enter for null)")
    else
        input=$(gum input --prompt "$prompt (press Enter for null)")
    fi
    
    if [ -z "$input" ]; then
        echo "null"
    else
        echo "$input"
    fi
}

# =============================================================================
# SYSTEM CHECKS
# =============================================================================

# Check if running as root (should not be)
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "This script should not be run as root"
        exit 1
    fi
}

# Check if components are installed
check_k3s_installed() { command -v k3s &> /dev/null || [ -f /usr/local/bin/k3s ]; }
check_argocd_installed() { kubectl get namespace argocd &>/dev/null 2>&1; }
check_helm_installed() { command -v helm &> /dev/null; }
check_k9s_installed() { command -v k9s &> /dev/null; }

# Show installation status of all components
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

# Check system prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v apt-get &> /dev/null; then
        print_error "This script is designed for Ubuntu/Debian systems"
        exit 1
    fi
    
    # Install required packages
    for pkg in curl wget coreutils; do
        if ! command -v $pkg &> /dev/null; then
            print_status "Installing $pkg..."
            sudo apt update -qq && sudo apt install -y $pkg
        fi
    done
    
    # System warnings
    if swapon --show | grep -q .; then
        print_warning "Swap is enabled. K3S may have issues."
    fi
    
    mem_total=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$mem_total" -lt 2048 ]; then
        print_warning "System has less than 2GB RAM. K3S may have issues."
    fi
    
    disk_free=$(df / | awk 'NR==2{printf "%.0f", $4}')
    if [ "$disk_free" -lt 10240 ]; then
        print_warning "Less than 10GB free disk space. K3S may have issues."
    fi
    
    # Port availability check
    local ports=(6443 30080 80 443 8080 2379 2380)
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Port $port is already in use."
        fi
    done
    
    print_success "Prerequisites check completed"
}

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

# Collect user input for configuration
collect_user_input() {
    print_status "Collecting configuration parameters..."
    
    detect_network_config
    
    # Check for existing config files
    existing_configs=($(ls k3s-config-*.env 2>/dev/null || true))
    if [ ${#existing_configs[@]} -gt 0 ]; then
        print_status "Found existing configuration files:"
        
        options=()
        for config in "${existing_configs[@]}"; do
            options+=("$config")
        done
        options+=("Create new configuration")
        
        config_choice=$(printf '%s\n' "${options[@]}" | gum choose --header "Select configuration:")
        
        if [ -n "$config_choice" ] && [ "$config_choice" != "Create new configuration" ]; then
            CONFIG_FILE="$config_choice"
            print_status "Loading configuration from $config_choice..."
            source "$config_choice"
            print_success "Configuration loaded successfully"
            return 0
        fi
    fi
    
    # Collect new configuration
    CUSTOMER=$(prompt_input "Company name (lowercase letters and numbers only):" "^[a-z0-9]+$" "Company name must only contain lowercase letters and numbers")
    CONFIG_FILE="k3s-config-$CUSTOMER.env"
    
    # Domain configuration via flag (default afcsoftware.com)
    if [ -n "$CUSTOM_DOMAIN" ]; then
        DOMAIN="$CUSTOM_DOMAIN"
    else
        DOMAIN="afcsoftware.com"
    fi
    
    # Container registry
    if [ "$SELF_HOSTED" = "true" ]; then
        CONTAINER_REGISTRY="swimagereg.azurecr.io"
        CONTAINER_REGISTRY_USERNAME=$(prompt_input "Container registry username:" "^.+$" "Username cannot be empty")
        CONTAINER_REGISTRY_PASSWORD=$(prompt_input "Container registry password:" "^.+$" "Password cannot be empty")
    else
        CONTAINER_REGISTRY=$(prompt_input "Container registry URL:" "" "" "imagesdevregistry.azurecr.io")
        CONTAINER_REGISTRY_USERNAME=$(prompt_input "Container registry username:" "^.+$" "Username cannot be empty")
        CONTAINER_REGISTRY_PASSWORD=$(prompt_input "Container registry password:" "^.+$" "Password cannot be empty")
    fi
    
    # Application admin
    APP_ADMIN_EMAIL=$(prompt_input "Application admin email:" "^[^@]+@[^@]+\.[^@]+$" "Must be a valid email address")
    
    # K3S configuration
    K3S_TOKEN=$(generate_random_string 32)
    print_status "Generated K3S token"
    
    if [ "$SELF_HOSTED" = "true" ]; then
        DEPLOYMENT_REVISION="HEAD"
    else
        DEPLOYMENT_REVISION=$(prompt_input "Deployment revision:" "" "" "HEAD")
    fi
    
    DEPLOY_DA_APP="true"
    DEPLOY_FC_APP=$(prompt_boolean "Deploy Financial Close application?" "false")
    
    # OAuth/SSO configuration (only for hosted deployments)
    # Dex configuration removed entirely; handled by private chart defaults
    
    # Intuit configuration (only for non-self-hosted)
    if [ "$SELF_HOSTED" = "true" ]; then
        print_status "Self-hosted deployment detected. Skipping Intuit configuration."
        INTUIT_CLIENT_ID="null"
        INTUIT_CLIENT_SECRET="null"
        INTUIT_REDIRECT_URI="null"
        ENCRYPTION_KEY="null"
    else
        INTUIT_CLIENT_ID=$(prompt_optional "Intuit client ID")
        INTUIT_CLIENT_SECRET=$(prompt_optional "Intuit client secret")
        INTUIT_REDIRECT_URI=$(prompt_optional "Intuit redirect URI")
        ENCRYPTION_KEY=$(prompt_optional "Encryption key")
    fi
    
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
    save_configuration
}

# Save configuration to file
save_configuration() {
    print_status "Saving configuration to $CONFIG_FILE..."
    
    cat > "$CONFIG_FILE" <<EOF
# K3S Configuration for $CUSTOMER
# Generated on $(date)

# Network Configuration
DETECTED_IP="$DETECTED_IP"
LOCAL_IP="$LOCAL_IP"
IS_PRIVATE_NETWORK="$IS_PRIVATE_NETWORK"

# Customer Configuration
CUSTOMER="$CUSTOMER"
DOMAIN="$DOMAIN"
SELF_HOSTED="$SELF_HOSTED"

# Container Registry
CONTAINER_REGISTRY="$CONTAINER_REGISTRY"
CONTAINER_REGISTRY_USERNAME="$CONTAINER_REGISTRY_USERNAME"
CONTAINER_REGISTRY_PASSWORD="$CONTAINER_REGISTRY_PASSWORD"

# Application Admin
APP_ADMIN_EMAIL="$APP_ADMIN_EMAIL"

# K3S Configuration
K3S_TOKEN="$K3S_TOKEN"
DEPLOYMENT_REVISION="$DEPLOYMENT_REVISION"
DEPLOY_DA_APP="$DEPLOY_DA_APP"
DEPLOY_FC_APP="$DEPLOY_FC_APP"

# OAuth/SSO Configuration (handled via private chart)
INTUIT_CLIENT_ID="$INTUIT_CLIENT_ID"
INTUIT_CLIENT_SECRET="$INTUIT_CLIENT_SECRET"
INTUIT_REDIRECT_URI="$INTUIT_REDIRECT_URI"
ENCRYPTION_KEY="$ENCRYPTION_KEY"

# Generated Credentials
POSTGRES_DATABASE="$POSTGRES_DATABASE"
POSTGRES_USERNAME="$POSTGRES_USERNAME"
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
BI_DEV_ROLE="$BI_DEV_ROLE"
ARGOWORKFLOWS_USERNAME="$ARGOWORKFLOWS_USERNAME"
ARGOWORKFLOWS_PASSWORD="$ARGOWORKFLOWS_PASSWORD"
FC_USER="$FC_USER"
FC_PASSWORD="$FC_PASSWORD"
FC_DATABASE="$FC_DATABASE"
MINIO_ROOT_USER="$MINIO_ROOT_USER"
MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD"
EOF
    
    chmod 600 "$CONFIG_FILE"
    print_success "Configuration saved"
}

# =============================================================================
# COMPONENT INSTALLATION
# =============================================================================

# Install K3S server
install_k3s() {
    print_status "Installing K3S..."
    
    # Clean up any existing installation
    print_status "Cleaning up any existing K3S installation..."
    sudo systemctl stop k3s 2>/dev/null || true
    sudo systemctl disable k3s 2>/dev/null || true
    sudo rm -rf /etc/rancher/k3s /var/lib/rancher/k3s /usr/local/bin/k3s /etc/systemd/system/k3s.service 2>/dev/null || true
    sudo systemctl daemon-reload 2>/dev/null || true
    
    sudo apt update -qq && sudo apt install -y ufw
    
    # Install K3S
    curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN sh -s - server --cluster-init --write-kubeconfig-mode 644 --bind-address 0.0.0.0 --advertise-address $LOCAL_IP
    
    print_status "Waiting for K3S to start..."
    sleep 30
    
    # Verify K3S is running
    if ! sudo systemctl is-active --quiet k3s; then
        print_error "K3S service is not running. Checking status..."
        sudo systemctl status k3s --no-pager
        print_error "K3S startup failed. Please check the status above."
        exit 1
    fi
    
    # Wait for API to be ready
    print_status "Waiting for K3S API to be ready..."
    timeout=300
    counter=0
    while [ $counter -lt $timeout ]; do
        if sudo kubectl get nodes &>/dev/null; then
            break
        fi
        sleep 5
        counter=$((counter + 5))
        gum spin --spinner dot --title "Waiting for K3S API..." -- sleep 5
    done
    
    if [ $counter -ge $timeout ]; then
        print_error "K3S API failed to become ready within $timeout seconds"
        print_status "Running diagnostics..."
        
        echo "=== K3S Service Status ==="
        sudo systemctl status k3s --no-pager || true
        
        echo "=== K3S Logs (last 20 lines) ==="
        sudo journalctl -u k3s --no-pager -n 20 || true
        
        echo "=== System Resources ==="
        free -h && df -h /
        
        echo "=== Port Status ==="
        sudo netstat -tuln | grep -E ':(6443|2379|2380|8080)' || true
        
        print_error "K3S startup failed. Please check the diagnostics above."
        print_status "Common solutions:"
        print_status "1. Disable swap: sudo swapoff -a"
        print_status "2. Ensure sufficient memory (2GB+) and disk space (10GB+)"
        print_status "3. Check if ports 6443, 2379, 2380 are available"
        print_status "4. Try rebooting the system"
        exit 1
    fi
    
    # Configure firewall
    sudo ufw allow 6443/tcp && sudo ufw allow 2379/tcp && sudo ufw allow 2380/tcp
    sudo ufw allow 8080/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
    sudo ufw insert 2 allow from any to any port 80 proto tcp comment "HTTP access"
    sudo ufw reload
    
    print_success "K3S installed and running successfully"
}

# Install Helm package manager
install_helm() {
    print_status "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    print_success "Helm installed successfully"
}

# Install ArgoCD GitOps controller
install_argocd() {
    print_status "Installing ArgoCD..."
    
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    
    if ! kubectl get nodes &>/dev/null; then
        print_error "K3S is not responding. Checking status..."
        sudo systemctl status k3s
        exit 1
    fi
    
    kubectl create namespace argocd || true
    
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --set server.metrics.enabled=true \
        --set controller.metrics.enabled=true \
        --set repoServer.metrics.enabled=true \
        --set applicationSet.metrics.enabled=true \
        --set server.service.type=NodePort \
        --set server.service.nodePort=30080
    
    print_status "Waiting for ArgoCD to be ready..."
    sleep 60
    
    print_success "ArgoCD installed successfully"
}

# Install K9s cluster management UI
install_k9s() {
    print_status "Installing K9s..."
    
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    
    wget -q https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_linux_amd64.deb
    sudo apt install -y ./k9s_linux_amd64.deb
    rm k9s_linux_amd64.deb
    
    # Configure kubeconfig
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.profile
    source ~/.bashrc
    source ~/.profile
    
    USER_HOME=$(eval echo ~$USER)
    sudo cp /etc/rancher/k3s/k3s.yaml "$USER_HOME/kubeconfig.yaml"
    sudo chown $USER:$USER "$USER_HOME/kubeconfig.yaml"
    sudo chmod 600 "$USER_HOME/kubeconfig.yaml"
    
    print_success "K9s installed successfully"
}

# =============================================================================
# ARGOCD CONFIGURATION
# =============================================================================

# Login to Helm registry
helm_login() {
    print_status "Logging into Helm registry..."
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    helm registry login $CONTAINER_REGISTRY -u $CONTAINER_REGISTRY_USERNAME -p $CONTAINER_REGISTRY_PASSWORD
    print_success "Helm registry login completed"
}

# Configure ArgoCD repositories
configure_argocd_repositories() {
    print_status "Configuring ArgoCD repositories..."
    
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

# Deploy ArgoCD application
deploy_argocd_application() {
    print_status "Deploying ArgoCD application..."
    
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
    targetRevision: "Script"
    path: "sw-public-chart"
    helm:
      values: |
        global:
          selfhosted: "$([ "$SELF_HOSTED" = "true" ] && echo "$CUSTOMER" || echo "")"
          hosted: "$([ "$SELF_HOSTED" = "false" ] && echo "$CUSTOMER" || echo "")"
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
    
    kubectl patch application initial-$CUSTOMER-app -n argocd \
        -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}' \
        --type merge || echo "Failed to patch ArgoCD app for refresh, continuing anyway"
    
    print_success "ArgoCD application deployed"
}

# Update ArgoCD application (reapply manifest)
update_argocd_application() {
    print_status "Updating ArgoCD application..."
    
    # Check if application exists
    if ! kubectl get application initial-$CUSTOMER-app -n argocd &>/dev/null; then
        print_error "ArgoCD application 'initial-$CUSTOMER-app' not found"
        print_status "Deploying new application instead..."
        deploy_argocd_application
        return
    fi
    
    # Reapply the entire manifest from the script
    print_status "Reapplying ArgoCD application manifest..."

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
    targetRevision: "Script"
    path: "sw-public-chart"
    helm:
      values: |
        global:
          selfhosted: "$([ "$SELF_HOSTED" = "true" ] && echo "$CUSTOMER" || echo "")"
          hosted: "$([ "$SELF_HOSTED" = "false" ] && echo "$CUSTOMER" || echo "")"
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
    
    print_success "ArgoCD application manifest reapplied"
    print_status "Check ArgoCD UI for sync status: http://$DETECTED_IP:30080"
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

# Display final information after installation
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
    echo "=== Application Access ==="
    echo "Your applications will be available at:"
    if [ "$DEPLOY_DA_APP" = "true" ]; then
        echo "  DA App: https://$CUSTOMER.$DOMAIN/da"
    fi
    if [ "$DEPLOY_FC_APP" = "true" ]; then
        echo "  FC App: https://$CUSTOMER.$DOMAIN/fc"
    fi
    if [ "$DEPLOY_DA_APP" != "true" ] && [ "$DEPLOY_FC_APP" != "true" ]; then
        echo "  No applications were configured for deployment"
    fi
    echo
    if [ "$IS_PRIVATE_NETWORK" = "true" ]; then
        echo "=== Private Network Notes ==="
        echo "You are running on a private network. External access may be limited."
        echo "Consider setting up port forwarding or VPN for external access."
    fi
}

# Main installation function
main() {
    gum style \
        --border normal \
        --margin "1" \
        --padding "1" \
        --border-foreground 212 \
        "K3S Setup Script" \
        "Lightweight Kubernetes with ArgoCD"
    echo
    
    check_root
    check_prerequisites
    
    if [ ! -t 0 ]; then
        echo "Detected pipe execution. For better experience, download and run the script directly:"
        echo "curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/Script/scripts/k3s-setup.sh -o k3s-setup.sh"
        echo "chmod +x k3s-setup.sh"
        echo "./k3s-setup.sh"
        echo ""
        echo "Continuing with pipe execution..."
        echo ""
    fi
    
    show_installation_status
    
    # Handle existing installations
    if [ "$K3S_INSTALLED" = "true" ] || [ "$HELM_INSTALLED" = "true" ] || [ "$ARGOCD_INSTALLED" = "true" ] || [ "$K9S_INSTALLED" = "true" ]; then
        print_warning "Some components are already installed!"
        
        choice=$(echo -e "Continue with installation (skip existing components)\nUpdate ArgoCD application only\nClean up and start fresh\nExit" | gum choose --header "Select option:")
        
        case $choice in
            "Continue with installation (skip existing components)")
                print_status "Continuing with installation, skipping existing components..."
                ;;
            "Update ArgoCD application only")
                print_status "Updating ArgoCD application only..."
                # Load existing configuration if available
                existing_configs=($(ls k3s-config-*.env 2>/dev/null || true))
                if [ ${#existing_configs[@]} -gt 0 ]; then
                    print_status "Found existing configuration files:"
                    options=()
                    for config in "${existing_configs[@]}"; do
                        options+=("$config")
                    done
                    
                    config_choice=$(printf '%s\n' "${options[@]}" | gum choose --header "Select configuration to use:")
                    
                    if [ -n "$config_choice" ]; then
                        CONFIG_FILE="$config_choice"
                        print_status "Loading configuration from $config_choice..."
                        source "$config_choice"
                        print_success "Configuration loaded successfully"
                        
                        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
                        update_argocd_application
                        print_success "Update completed!"
                        exit 0
                    else
                        print_error "No configuration selected"
                        exit 1
                    fi
                else
                    print_error "No existing configuration found. Please run full installation first."
                    exit 1
                fi
                ;;
            "Clean up and start fresh")
                print_status "Cleaning up existing installation..."
                if [ -f "./k3s-cleanup.sh" ]; then
                    ./k3s-cleanup.sh --cleanup-all
                else
                    print_warning "Cleanup script not found. Please run cleanup manually."
                    exit 1
                fi
                ;;
            "Exit")
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option, exiting..."
                exit 1
                ;;
        esac
    fi
    
    collect_user_input
    
    # Install components (skip if already installed)
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
    configure_argocd_health_scripts
    
    display_final_info
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Initialize gum
check_gum

# Auto-download and run network setup if not already present
auto_setup_network() {
    if [ ! -f "./network-setup.sh" ]; then
        print_status "Downloading network setup script..."
        curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/Script/scripts/network-setup.sh -o network-setup.sh
        chmod +x network-setup.sh
        print_success "Network setup script downloaded"
    fi
    
    if [ ! -f "./k3s-cleanup.sh" ]; then
        print_status "Downloading cleanup script..."
        curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/Script/scripts/k3s-cleanup.sh -o k3s-cleanup.sh
        chmod +x k3s-cleanup.sh
        print_success "Cleanup script downloaded"
    fi
    
    # Run network setup if this is a fresh installation
    if [ "$1" != "--update" ] && [ "$1" != "--help" ] && [ "$1" != "-h" ]; then
        print_status "Running network setup check..."
        ./network-setup.sh
        echo
        print_status "Continuing with K3S installation..."
    fi
}

# Command line options
case "${1:-}" in
    --update)
        print_status "Update mode: Updating ArgoCD application only..."
        
        # Load existing configuration
        existing_configs=($(ls k3s-config-*.env 2>/dev/null || true))
        if [ ${#existing_configs[@]} -eq 0 ]; then
            print_error "No configuration files found. Please run full installation first."
            exit 1
        fi
        
        if [ ${#existing_configs[@]} -eq 1 ]; then
            CONFIG_FILE="${existing_configs[0]}"
        else
            print_status "Multiple configuration files found:"
            for i in "${!existing_configs[@]}"; do
                echo "$((i+1)). ${existing_configs[$i]}"
            done
            
            read -p "Select configuration (1-${#existing_configs[@]}): " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#existing_configs[@]} ]; then
                CONFIG_FILE="${existing_configs[$((choice-1))]}"
            else
                print_error "Invalid selection"
                exit 1
            fi
        fi
        
        print_status "Loading configuration from $CONFIG_FILE..."
        source "$CONFIG_FILE"
        print_success "Configuration loaded successfully"
        
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        update_argocd_application
        print_success "Update completed!"
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --update              Update ArgoCD application only (requires existing config)"
        echo "  --swdeployment        Hosted deployment (not self-hosted)"
        echo "  --custom-domain <d>   Override domain (default: afcsoftware.com)"
        echo "  --help, -h            Show this help message"
        echo
        echo "If no option is provided, interactive installation will be performed."
        ;;
    --swdeployment|--custom-domain)
        # Run normal flow with flags parsed
        auto_setup_network "$1"
        parse_cli_flags "$@"
        main "$@"
        ;;
    "")
        # Auto-download scripts and run network setup
        auto_setup_network "$1"
        parse_cli_flags "$@"
        main "$@"
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac 