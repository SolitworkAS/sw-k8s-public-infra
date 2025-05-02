# K3s Infrastructure Deployment

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [Prerequisites](#prerequisites)
5. [Installation](#installation)
6. [Configuration](#configuration)
7. [Deployment](#deployment)
8. [Security Features](#security-features)
9. [Restore Procedure](#restore-procedure)
10. [Variables Reference](#variables-reference)

## Overview
This project automates the deployment of a secure, production-ready K3s cluster on Azure. K3s is a lightweight Kubernetes distribution that provides all the essential features of Kubernetes while being optimized for resource-constrained environments.

Key features:
- Automated K3s cluster deployment with hardened security configurations
- Integrated container registry support
- PostgreSQL database setup with secure credentials
- ArgoCD for GitOps-based application deployment
- SSO integration (GitHub, Microsoft, and custom SSO providers)
- Automated backup and recovery for VMs
- Helm chart management for application deployment

## Architecture
The infrastructure consists of:
1. **Control Plane**: Single master node running K3s server
2. **Networking**: 
   - Virtual Network with subnet
   - Network Security Group with restricted access
   - Public IP for external access
3. **Storage**: 
   - Azure Storage integration
   - MinIO for object storage
4. **Security**:
   - Pod Security Admission (PSA) with restricted defaults
   - Secrets encryption
   - Audit logging
   - TLS configuration
5. **Application Management**:
   - ArgoCD for GitOps
   - Helm for package management
   - K9s for cluster management

## Project Structure
```
k3s/
├── main/              # Main infrastructure components
│   └── k3s/          # K3s-specific configurations
│       └── security/ # Security configurations
├── k3s-workers/      # Worker node configurations
├── main.tf           # Main Terraform configuration
├── variables.tf      # Variable definitions
├── output.tf         # Output definitions
└── provider.tf       # Provider configuration
```

## Prerequisites
- Azure subscription with appropriate permissions
- Terraform (v1.1.0 or later)
- Azure CLI
- SSH key pair
- Container registry credentials
- SSO provider credentials (if using SSO)

## Installation
1. Clone the repository
2. Navigate to the k3s directory
3. Initialize Terraform:
   ```bash
   terraform init
   ```

## Configuration
Create a `terraform.tfvars` file with the following structure:

```hcl
# General Configuration
location = "northeurope"  # Azure region
customer = "customer1"    # Customer identifier (lowercase letters and numbers only)
domain   = "afcsoftware.com"

# Container Registry
container_registry          = "imagesdevregistry.azurecr.io"
container_registry_username = "your-registry-username"
container_registry_password = "your-registry-password"

# Database Configuration
database_user     = "admin"
database_password = "your-secure-password"

# Application Admin
app_admin_email      = "admin@example.com"
app_admin_first_name = "Admin"
app_admin_last_name  = "User"

# SSH Configuration
ssh_public_key  = "your-public-key"
ssh_private_key = "your-private-key"

# SSO Configuration (Optional)
github_client_id     = "your-github-client-id"
github_client_secret = "your-github-client-secret"

sso_issuer        = "your-sso-issuer"
sso_client_id     = "your-sso-client-id"
sso_client_secret = "your-sso-client-secret"

microsoft_client_id     = "your-microsoft-client-id"
microsoft_client_secret = "your-microsoft-client-secret"
```

## Deployment
To deploy the infrastructure:
```bash
terraform plan
terraform apply
```

## Security Features
The deployment includes several security measures:
1. **Pod Security**: Restricted security context by default
2. **Secrets Encryption**: Kubernetes secrets are encrypted at rest
3. **Audit Logging**: Comprehensive audit logging with 30-day retention
4. **Network Security**: 
   - Restricted inbound access
   - TLS 1.2+ with secure cipher suites
   - SSH access only
5. **Backup**: Automated VM backups with 7-day retention

## Restore Procedure
In case of VM failure or data corruption, follow these steps to restore from a backup:

1. **Stop the VM**:
   - Navigate to the Azure Portal
   - Go to the Virtual Machine resource
   - Click "Stop" and wait for the VM to fully stop

2. **Access Recovery Services Vault**:
   - Navigate to the Recovery Services Vault resource
   - The vault name follows the pattern: `{customer}-vm-backup-vault`

3. **Select Backup Item**:
   - Click on "Backup items" in the left menu
   - Select "Azure Virtual Machine"
   - Choose the VM that needs restoration

4. **Choose Restore Point**:
   - Click on "Restore VM"
   - Select "Restore existing" (do not select "Create new")
   - Choose the desired restore point from the list
   - Review the restore point details and click "Next"

5. **Configure Restore Settings**:
   - Select the same virtual network and subnet
   - Choose "Restore disks" option
   - Click "Restore" to start the process

6. **Monitor Restore Progress**:
   - Monitor the restore job in the "Backup jobs" section
   - Wait for the restore to complete

7. **Start the VM**:
   - Once restore is complete, go back to the VM resource
   - Click "Start" to bring the VM back online

8. **Verify Restoration**:
   - Connect to the VM via SSH
   - Verify that all services are running correctly
   - Check application functionality

**Important Notes**:
- The restore process may take several minutes depending on the backup size
- All data after the selected restore point will be lost
- Ensure you have the necessary permissions to perform restore operations
- It's recommended to take a snapshot of the current state before restoring if possible

## Variables Reference

### General Variables
| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| location | Azure region | northeurope | No |
| customer | Customer identifier | - | Yes |
| domain | Domain for proxy | afcsoftware.com | No |

### Container Registry
| Variable | Description | Required |
|----------|-------------|----------|
| container_registry | Registry URL | Yes |
| container_registry_username | Registry username | Yes |
| container_registry_password | Registry password | Yes |

### Database
| Variable | Description | Required |
|----------|-------------|----------|
| database_user | Admin username | Yes |
| database_password | Admin password | Yes |

### Application Admin
| Variable | Description | Required |
|----------|-------------|----------|
| app_admin_email | Admin email | Yes |
| app_admin_first_name | Admin first name | Yes |
| app_admin_last_name | Admin last name | Yes |

### SSO (Optional)
| Variable | Description | Required |
|----------|-------------|----------|
| github_client_id | GitHub OAuth client ID | No |
| github_client_secret | GitHub OAuth client secret | No |
| sso_issuer | SSO issuer URL | No |
| sso_client_id | SSO client ID | No |
| sso_client_secret | SSO client secret | No |
| microsoft_client_id | Microsoft OAuth client ID | No |
| microsoft_client_secret | Microsoft OAuth client secret | No |
