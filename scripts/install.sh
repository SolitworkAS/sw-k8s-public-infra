#!/bin/bash

# Simple installation script for K3S Setup
# This script downloads and executes the main K3S setup script

set -e

echo "=========================================="
echo "        K3S Setup - Installation"
echo "=========================================="
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: This script should not be run as root"
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    sudo apt update
    sudo apt install -y curl
fi

# Download the main script
echo "Downloading K3S setup script..."
curl -fsSL https://raw.githubusercontent.com/SolitworkAS/sw-k8s-public-infra/Script/scripts/install.sh -o k3s-setup.sh

# Make it executable
chmod +x k3s-setup.sh

echo "Script downloaded successfully!"
echo "Starting K3S setup..."
echo

# Execute the script
./k3s-setup.sh 