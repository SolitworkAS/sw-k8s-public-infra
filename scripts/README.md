# K3S Setup Scripts

**Simple scripts to set up a Kubernetes cluster with ArgoCD on Ubuntu systems.**

## What This Does

This script automatically installs and configures:
- **K3S** - A lightweight Kubernetes cluster
- **ArgoCD** - A web interface to manage your applications
- **Helm** - Package manager for Kubernetes
- **K9s** - A terminal-based tool to manage your cluster


## Quick Installation

### Option 1: One-liner (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/Script/scripts/k3s-setup.sh | bash
```

### Option 2: Download and run
```bash
curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/Script/scripts/k3s-setup.sh -o k3s-setup.sh
chmod +x k3s-setup.sh
./k3s-setup.sh
```

**What happens when you run it:**
1. Downloads additional helper scripts automatically
2. Checks your network and system requirements
3. Asks you a few questions about your setup
4. Installs everything automatically
5. Shows you how to access the web interface

## System Requirements

**Before running the script, make sure you have:**

- **Operating System**: Ubuntu or Debian Linux
- **User**: A regular user account (NOT root) with sudo privileges
- **Internet**: Working internet connection
- **Hardware**: 
  - At least 2GB RAM
  - At least 10GB free disk space
- **Network**: Ports 6443, 30080, 80, 443 should be available

## What You'll Need to Provide

The script will ask you for:
- **Customer name** (lowercase letters and numbers only)
- **Domain name** (or app name for local development)
- **Container registry** credentials (username/password)
- **Admin user** details (email, first name, last name)
- **Optional settings** like OAuth/SSO (you can skip these)

## After Installation

Once complete, you'll have access to:
- **ArgoCD Web Interface**: `http://YOUR_SERVER_IP:30080`
- **Configuration file**: `~/kubeconfig.yaml` (for command line access)
- **Domain**: Your configured domain or local development domain

## Updating Your Setup

If you need to update the configuration later:

```bash
./k3s-setup.sh --update
```

This will:
- Load your existing configuration
- Apply any new settings from the script
- Update your ArgoCD applications

## Troubleshooting

### Common Problems

**1. Script fails to start**
- Make sure you're not running as root
- Check you have internet connection
- Verify you have at least 2GB RAM and 10GB disk space

**2. Can't access the web interface**
- Check if the script completed successfully
- Try accessing `http://localhost:30080` from the server
- Check firewall settings: `sudo ufw status`

**3. K3S won't start**
- Disable swap: `sudo swapoff -a`
- Check system resources: `free -h && df -h`
- Look at logs: `sudo journalctl -u k3s -f`

### Getting Help

If you encounter issues:
1. Check the error messages in the terminal
2. Look at the troubleshooting section above
3. Check system resources and network connectivity
4. Try running the cleanup script and starting fresh

## Cleanup (If Needed)

To remove everything and start over:

```bash
./k3s-cleanup.sh
```

This will show you options to:
- Remove specific components
- Remove everything and start fresh
- Check what's currently installed

## Script Files

The installation creates these files:
- `k3s-setup.sh` - Main installation script
- `network-setup.sh` - Network diagnostics (downloaded automatically)
- `k3s-cleanup.sh` - Cleanup script (downloaded automatically)
- `k3s-config-*.env` - Your configuration files

## Need More Help?

If you're still having trouble:
1. Check that your system meets all requirements
2. Make sure you have a stable internet connection
3. Try running the network setup first: `./network-setup.sh`
4. Check the logs for specific error messages 