# K3S Setup Script

This script automates the complete installation and configuration of a K3S cluster with ArgoCD, Helm, K9s, and all necessary components based on the Terraform configuration.

## Overview

The `k3s-setup.sh` script converts all the functionality from the Terraform configuration (`k3s/main/k3s/main.tf`) into a single bash script that:

1. Prompts for all necessary configuration parameters
2. Installs and configures K3S with security hardening
3. Installs Helm, ArgoCD, and K9s
4. Configures container registry authentication
5. Sets up ArgoCD repositories
6. Deploys the complete application stack

## Prerequisites

- Ubuntu/Debian system (tested on Ubuntu 24.04 LTS)
- Internet connectivity
- Sudo privileges
- At least 4GB RAM and 20GB disk space

## Quick Start

### Linux/Unix Systems

#### Option 1: Direct Download and Execute
```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/main/scripts/k3s-setup.sh -o k3s-setup.sh

# Make it executable
chmod +x k3s-setup.sh

# Run the script
./k3s-setup.sh
```

#### Option 2: One-liner Execution
```bash
curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/main/scripts/k3s-setup.sh | bash
```





## Configuration Parameters

The script will prompt you for the following parameters:

### Required Parameters
- **Customer**: Shorthand abbreviation (lowercase letters and numbers only)
- **Container Registry Username**: Registry authentication username
- **Container Registry Password**: Registry authentication password
- **Application Admin Email**: Valid email address for admin user
- **Application Admin First Name**: Admin user's first name
- **Application Admin Last Name**: Admin user's last name

### Optional Parameters (with defaults)
- **Domain**: Domain name (default: afcsoftware.com)
- **Self-hosted**: Whether this is self-hosted (default: true)
- **Container Registry URL**: Registry URL (default: imagesdevregistry.azurecr.io)
- **K3S Token**: Auto-generated if not provided
- **Deployment Revision**: Git revision to deploy (default: HEAD)
- **Deploy DA App**: Whether to deploy DA application (default: false)
- **Deploy FC App**: Whether to deploy FC application (default: false)

### OAuth/SSO Parameters (optional)
- GitHub Client ID and Secret
- SSO Issuer, Client ID, and Secret
- Microsoft Client ID and Secret
- Intuit Client ID, Secret, and Redirect URI
- Encryption Key

## What the Script Does

1. **Prerequisites Check**: Verifies system requirements and installs necessary packages
2. **User Input Collection**: Prompts for all configuration parameters with validation
3. **K3S Installation**: Installs K3S with cluster initialization
4. **Security Hardening**: Applies PSA policies, audit logging, and kernel hardening
5. **Helm Installation**: Installs Helm package manager
6. **ArgoCD Installation**: Installs ArgoCD with metrics enabled
7. **K9s Installation**: Installs K9s cluster management tool
8. **Registry Authentication**: Logs into the container registry
9. **Repository Configuration**: Sets up ArgoCD repositories (public and private)
10. **Application Deployment**: Deploys the complete application stack via ArgoCD

## Generated Credentials

The script automatically generates secure random credentials for:

- PostgreSQL database, username, and password
- MinIO root user and password
- ArgoWorkflows username and password
- Financial Close user, password, and database
- BI Developer role

## Output and Access Information

After successful completion, the script displays:

- Configuration summary
- Generated credentials
- Access information including:
  - Kubeconfig location
  - ArgoCD UI URL
  - Next steps for cluster management

## Security Features

- Pod Security Admission (PSA) with restricted policy
- Audit logging enabled
- Secrets encryption
- Kernel hardening
- Firewall configuration (UFW)
- TLS cipher suite restrictions

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the script is executable (`chmod +x k3s-setup.sh`)
2. **Network Issues**: Verify internet connectivity and firewall settings
3. **Disk Space**: Ensure sufficient disk space (minimum 20GB recommended)
4. **Memory**: Ensure sufficient RAM (minimum 4GB recommended)

### Logs and Debugging

- K3S logs: `sudo journalctl -u k3s -f`
- ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`
- Application logs: `kubectl logs -n <namespace> -l app=<app-name>`

### Manual Verification

```bash
# Check K3S status
sudo systemctl status k3s

# Check cluster nodes
kubectl get nodes

# Check ArgoCD pods
kubectl get pods -n argocd

# Check all namespaces
kubectl get namespaces
```

## Post-Installation

After successful installation:

1. **Access ArgoCD UI**: Navigate to `http://<public-ip>:8080`
2. **Monitor Deployments**: Use ArgoCD UI or `kubectl get applications -n argocd`
3. **Cluster Management**: Use K9s (`k9s`) for interactive cluster management
4. **Export Kubeconfig**: `export KUBECONFIG=/home/$USER/kubeconfig.yaml`

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the script logs and Kubernetes logs
3. Ensure all prerequisites are met
4. Verify network connectivity and firewall settings

## Script Features

- **Input Validation**: All user inputs are validated with appropriate regex patterns
- **Error Handling**: Comprehensive error handling with colored output
- **Progress Indicators**: Clear status messages throughout the process
- **Automatic Credential Generation**: Secure random generation of all required credentials
- **Idempotent Operations**: Safe to re-run if interrupted
- **Colored Output**: Easy-to-read status messages with color coding

## Files in this Directory

- `k3s-setup.sh` - Main K3S setup script (Linux/Unix)
- `README.md` - This documentation file 