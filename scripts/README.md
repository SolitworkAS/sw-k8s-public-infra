# K3S Setup Scripts

Scripts for setting up K3S, ArgoCD, and related components on Ubuntu systems.

## Scripts

### `k3s-setup.sh` - Main Setup Script
- Installs K3S, Helm, ArgoCD, and K9s
- Detects network configuration automatically
- Configures nip.io domains for private networks
- Handles resume from partial installations

### `network-setup.sh` - Network Helper
- Diagnoses network configuration
- Tests connectivity and port availability
- Configures firewall rules

### `k3s-cleanup.sh` - Cleanup Script
- Removes installed components
- Shows installation status
- Supports partial cleanup

## Quick Start

```bash
# Download scripts
curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/Script/scripts/k3s-setup.sh -o k3s-setup.sh
curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/Script/scripts/network-setup.sh -o network-setup.sh
curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/Script/scripts/k3s-cleanup.sh -o k3s-cleanup.sh
chmod +x k3s-setup.sh network-setup.sh k3s-cleanup.sh

# Optional: Check network
./network-setup.sh

# Run setup
./k3s-setup.sh
```

## Configuration

The script prompts for:
- Customer name (lowercase, alphanumeric)
- Domain (or app name for nip.io)
- Container registry credentials
- Application admin details
- OAuth/SSO settings (optional)
- Deployment options

**Configuration files**: Settings are saved to `k3s-config-<customer>.env` and can be reloaded on subsequent runs.

## Network Support

- **Public networks**: Uses detected public IP
- **Private networks**: Automatically configures nip.io domains
- **Local development**: Uses local IP addresses

## Access

After installation:
- **ArgoCD UI**: `http://<ip>:30080`
- **Kubeconfig**: `~/kubeconfig.yaml`
- **Domain**: Configured domain or nip.io domain

## Cleanup

```bash
# Interactive menu
./k3s-cleanup.sh

# Command-line options
./k3s-cleanup.sh --status              # Show status
./k3s-cleanup.sh --resume              # Resume installation
./k3s-cleanup.sh --cleanup-all         # Remove everything
```

## Troubleshooting

### Common Issues

1. **K3S fails to start**
   - Check resources: `free -h && df -h`
   - Check logs: `sudo journalctl -u k3s -f`
   - Disable swap: `sudo swapoff -a`

2. **ArgoCD not accessible**
   - Check pods: `kubectl get pods -n argocd`
   - Check service: `kubectl get svc -n argocd`
   - Check firewall: `sudo ufw status`

3. **nip.io domains not working**
   - Test: `nslookup test.127.0.0.1.nip.io`
   - Use local IP directly if needed

### Network Issues

- **Private networks**: Use SSH port forwarding or ngrok
- **Corporate networks**: Check proxy and firewall settings

## Prerequisites

- Ubuntu/Debian system
- Non-root user with sudo privileges
- Internet connectivity
- At least 2GB RAM, 10GB disk space 