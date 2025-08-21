#!/bin/bash
set -e

echo "=== Starting provisioning ==="

# Wait a bit to ensure cloud-init package installations are complete
echo "Waiting for cloud-init package installations to complete..."
sleep 10

# Check if apt is locked and wait if necessary
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "Waiting for apt lock to be released..."
    sleep 5
done

# Update package list with retry logic
echo "Updating package list..."
for i in {1..3}; do
    if sudo apt-get update; then
        break
    else
        echo "Attempt $i failed, retrying in 10 seconds..."
        sleep 10
    fi
done

# Upgrade existing packages (only if not done by cloud-init)
echo "Upgrading existing packages..."
sudo apt-get upgrade -y

# Install additional packages (avoid duplicates from cloud-init)
echo "Installing additional packages..."
sudo apt-get install -y \
    dkms \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Try to install linux headers if available (optional for cloud images)
echo "Attempting to install linux headers..."
if sudo apt-get install -y linux-headers-$(uname -r) 2>/dev/null; then
    echo "Linux headers installed successfully"
else
    echo "Linux headers not available for this kernel version (normal for cloud images)"
fi

# Verify critical installations
echo "Verifying installations..."
curl --version || echo "curl not found"
wget --version || echo "wget not found"  
vim --version || echo "vim not found"
git --version || echo "git not found"

# Test network connectivity
echo "Testing network connectivity..."
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "Network connectivity: OK"
else
    echo "Warning: No internet connectivity"
fi

echo "=== Provisioning completed ==="
