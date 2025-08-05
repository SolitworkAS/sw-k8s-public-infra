# K3S Setup Scripts

This directory contains improved scripts for setting up K3S, ArgoCD, and related components on Ubuntu systems.

## Scripts Overview

### 1. `k3s-setup.sh` - Main Setup Script
The main script that automates the complete K3S installation and configuration process.

**Key Improvements:**
- **Universal Network Support**: Works on any Ubuntu machine, not just Azure VMs
- **Smart IP Detection**: Automatically detects public and private IP addresses
- **nip.io Integration**: Automatically configures nip.io domains for local development
- **Enhanced Error Handling**: Better error messages and troubleshooting information
- **Port Availability Checks**: Verifies required ports are available before installation
- **Firewall Configuration**: Automatically configures UFW firewall rules

### 2. `network-setup.sh` - Network Configuration Helper
A companion script that helps diagnose and configure network settings.

**Features:**
- Network interface detection
- Port availability checking
- External connectivity testing
- Firewall configuration
- nip.io resolution testing
- Troubleshooting tips

## Usage

### Prerequisites
- Ubuntu/Debian system
- Non-root user with sudo privileges
- Internet connectivity

### Quick Start

1. **Download the scripts:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/main/scripts/k3s-setup.sh -o k3s-setup.sh
   curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/main/scripts/network-setup.sh -o network-setup.sh
   chmod +x k3s-setup.sh network-setup.sh
   ```

2. **Optional: Run network setup first (recommended for troubleshooting):**
   ```bash
   ./network-setup.sh
   ```

3. **Run the main setup script:**
   ```bash
   ./k3s-setup.sh
   ```

### Network Scenarios

#### Public Network (Direct Internet Access)
- Script automatically detects public IP
- Uses standard domain configuration
- Full external access available

#### Private Network (Behind NAT/Firewall)
- Script detects private IP and warns user
- Automatically configures nip.io domains
- Provides local access URLs
- Suggests port forwarding options

#### Local Development
- Uses local IP addresses
- Configures nip.io for local domain resolution
- Provides troubleshooting guidance

## Configuration Parameters

The script will prompt for the following parameters:

### Required Parameters
- **Customer**: Lowercase letters and numbers only
- **Domain**: Domain name (or app name for nip.io)
- **Container Registry**: Registry URL, username, and password
- **Application Admin**: Email, first name, and last name

### Optional Parameters
- **K3S Token**: Auto-generated if not provided
- **OAuth/SSO Configuration**: GitHub, Microsoft, Intuit, and custom SSO settings
- **Deployment Options**: DA and FC app deployment flags

## Generated Credentials

The script automatically generates secure random credentials for:
- PostgreSQL database, username, and password
- MinIO root user and password
- ArgoCD workflows credentials
- Financial Close app credentials

## Access Information

After successful installation:

### ArgoCD UI
- **Public Network**: `http://<public-ip>:30080`
- **Private Network**: `http://<local-ip>:30080`

### Kubeconfig
- Location: `/home/<user>/kubeconfig.yaml`
- Usage: `export KUBECONFIG=/home/<user>/kubeconfig.yaml`

### Domain Access
- **Public Network**: Uses configured domain
- **Private Network**: Uses nip.io domain (e.g., `myapp.192.168.1.100.nip.io`)

## Troubleshooting

### Common Issues

1. **K3S fails to start**
   - Check system resources: `free -h && df -h`
   - Check K3S logs: `sudo journalctl -u k3s -f`
   - Disable swap: `sudo swapoff -a`

2. **ArgoCD not accessible**
   - Check pods: `kubectl get pods -n argocd`
   - Check service: `kubectl get svc -n argocd`
   - Check firewall: `sudo ufw status`

3. **nip.io domains not working**
   - Test resolution: `nslookup test.127.0.0.1.nip.io`
   - Use local IP directly if needed
   - Check `/etc/hosts` for local development

### Network-Specific Issues

#### Private Network
- Consider SSH port forwarding: `ssh -L 30080:localhost:30080 user@server`
- Use ngrok for temporary access: `ngrok http 30080`
- Configure router port forwarding

#### Corporate Network
- Check proxy settings
- Verify firewall allows required ports
- Contact network administrator if needed

## Security Considerations

- Script runs as non-root user
- UFW firewall is automatically configured
- Random credentials are generated for all services
- K3S token is auto-generated if not provided
- Sensitive data is not logged

## Differences from Azure Terraform

The script provides the same functionality as the Azure Terraform configuration but works on any Ubuntu machine:

| Feature | Azure Terraform | Script |
|---------|----------------|---------|
| IP Detection | Uses Azure public IP | Multi-method detection |
| Network Config | Azure-specific | Universal |
| Domain Setup | Manual configuration | Automatic nip.io for private networks |
| Firewall | Azure NSG | UFW |
| Installation | VM extension | Direct installation |

## Support

For issues or questions:
1. Run `./network-setup.sh` for diagnostics
2. Check the troubleshooting section above
3. Review K3S and ArgoCD logs
4. Ensure all prerequisites are met 