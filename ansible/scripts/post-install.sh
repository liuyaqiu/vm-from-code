#!/bin/bash
set -e

echo "========================================="
echo "Post-Installation Script"
echo "========================================="
echo ""

echo "Installing mise..."
sudo apt update -y && sudo apt install -y gpg sudo wget curl
sudo install -dm 755 /etc/apt/keyrings
wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | sudo tee /etc/apt/keyrings/mise-archive-keyring.gpg 1> /dev/null
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list
sudo apt update
sudo apt install -y mise

echo "========================================="
echo "Post-Installation Verification Script"
echo "========================================="
echo ""

# Verify Bazelisk installation
echo "✓ Verifying Bazelisk installation..."
if command -v bazel &> /dev/null; then
    bazel version
    echo ""
else
    echo "❌ Bazelisk not found in PATH"
    exit 1
fi

# Verify Fastfetch installation
echo "✓ Verifying Fastfetch installation..."
if command -v fastfetch &> /dev/null; then
    fastfetch --version
    echo ""
else
    echo "❌ Fastfetch not found in PATH"
    exit 1
fi

# Verify Mise installation
echo "✓ Verifying Mise installation..."
if command -v mise &> /dev/null; then
    mise --version
    echo ""
else
    echo "❌ Mise not found in PATH"
    exit 1
fi

# Verify Docker installation (if installed)
if command -v docker &> /dev/null; then
    echo "✓ Verifying Docker installation..."
    docker --version
    docker compose version
    echo ""
fi

echo "========================================="
echo "✅ All installations verified successfully!"
echo "========================================="
