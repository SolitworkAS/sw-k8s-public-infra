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
    
    print_success "Prerequisites check completed"
}

# Function to collect user input
collect_user_input() {
    print_status "Collecting configuration parameters..."
    
    # General variables
    CUSTOMER=$(prompt_input "Enter customer shorthand (lowercase letters and numbers only)" "^[a-z0-9]+$" "Customer must only contain lowercase letters and numbers")
    DOMAIN=$(prompt_input "Enter domain (e.g., afcsoftware.com)" "" "" "afcsoftware.com")
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
    
    # Install K3S
    curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN sh -s - server --cluster-init --write-kubeconfig-mode 644
    
    # Configure firewall
    sudo ufw allow 6443/tcp
    sudo ufw allow 2379/tcp
    sudo ufw allow 2380/tcp
    sudo ufw reload
    
    print_success "K3S installed successfully"
}

# Function to apply K3S hardening
apply_k3s_hardening() {
    print_status "Applying K3S hardening..."
    
    # Stop K3S service
    sudo systemctl stop k3s || true
    
    # Kernel sysctl configuration
    echo 'vm.panic_on_oom=0
vm.overcommit_memory=1
kernel.panic=10
kernel.panic_on_oops=1' | sudo tee /etc/sysctl.d/90-kubelet.conf > /dev/null
    sudo sysctl -p /etc/sysctl.d/90-kubelet.conf
    
    # Create PSA configuration
    sudo mkdir -p /var/lib/rancher/k3s/server
    sudo tee /var/lib/rancher/k3s/server/psa.yaml > /dev/null <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: PodSecurity
    configuration:
      apiVersion: pod-security.admission.config.k8s.io/v1beta1
      kind: PodSecurityConfiguration
      defaults:
        enforce: "restricted"
        enforce-version: "latest"
        audit: "restricted"
        audit-version: "latest"
        warn: "restricted"
        warn-version: "latest"
      exemptions:
        usernames: []
        runtimeClasses: []
        namespaces: [kube-system, cis-operator-system]
EOF
    
    # Create audit policy
    sudo tee /var/lib/rancher/k3s/server/audit.yaml > /dev/null <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
EOF
    
    # Create K3S main configuration
    sudo mkdir -p /etc/rancher/k3s
    sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<EOF
protect-kernel-defaults: true
secrets-encryption: true

kube-apiserver-arg:
  - "admission-control-config-file=/var/lib/rancher/k3s/server/psa.yaml"
  - "audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log"
  - "audit-policy-file=/var/lib/rancher/k3s/server/audit.yaml"
  - "audit-log-maxage=30"
  - "audit-log-maxbackup=10"
  - "audit-log-maxsize=100"

kube-controller-manager-arg:
  - "terminated-pod-gc-threshold=10"

kubelet-arg:
  - "streaming-connection-idle-timeout=5m"
  - "tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
EOF
    
    # Reload daemon and start K3S
    sudo systemctl daemon-reload
    sleep 5
    sudo systemctl start k3s
    
    print_success "K3S hardening applied successfully"
}

# Function to install Helm
install_helm() {
    print_status "Installing Helm..."
    
    # Wait for K3S to be ready
    echo "Waiting for K3S to be fully ready..."
    sleep 60
    
    # Install Helm
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    
    # Verify installation
    helm version
    
    print_success "Helm installed successfully"
}

# Function to install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    # Create namespace
    kubectl create namespace argocd || true
    
    # Add ArgoCD Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Install ArgoCD
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --set server.metrics.enabled=true \
        --set controller.metrics.enabled=true \
        --set repoServer.metrics.enabled=true \
        --set applicationSet.metrics.enabled=true
    
    # Wait for ArgoCD to be ready
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
    
    # Ensure kubeconfig is readable
    sudo cp /etc/rancher/k3s/k3s.yaml /home/$USER/kubeconfig.yaml
    sudo chown $USER:$USER /home/$USER/kubeconfig.yaml
    sudo chmod 600 /home/$USER/kubeconfig.yaml
    
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
    
    # Get the public IP address
    PUBLIC_IP=$(curl -s ifconfig.me)
    
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
          publicIp: "$PUBLIC_IP"
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
    echo "Public IP: $(curl -s ifconfig.me)"
    echo
    echo "=== Generated Credentials ==="
    echo "Postgres Database: $POSTGRES_DATABASE"
    echo "Postgres Username: $POSTGRES_USERNAME"
    echo "Postgres Password: $POSTGRES_PASSWORD"
    echo "MinIO Root User: $MINIO_ROOT_USER"
    echo "MinIO Root Password: $MINIO_ROOT_PASSWORD"
    echo
    echo "=== Access Information ==="
    echo "Kubeconfig location: /home/$USER/kubeconfig.yaml"
    echo "ArgoCD UI: http://$(curl -s ifconfig.me):8080"
    echo
    echo "=== Next Steps ==="
    echo "1. Access ArgoCD UI to monitor deployments"
    echo "2. Use 'kubectl get pods -A' to check pod status"
    echo "3. Use 'k9s' for cluster management"
    echo "4. Export KUBECONFIG: export KUBECONFIG=/home/$USER/kubeconfig.yaml"
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
    
    # Collect user input
    collect_user_input
    
    # Install and configure components
    install_k3s
    apply_k3s_hardening
    install_helm
    install_argocd
    install_k9s
    helm_login
    configure_argocd_repositories
    deploy_argocd_application
    
    # Display final information
    display_final_info
}

# Run main function
main "$@" 