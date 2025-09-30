#!/bin/bash
set -e

echo "=== Setting up static DHCP reservations for libvirt default network ==="

# First, stop the default network
echo "Stopping default network..."
sudo virsh net-destroy default || echo "Network may already be stopped"

# Undefine the existing network
echo "Undefining existing default network..."
sudo virsh net-undefine default

# Define the updated network with our static reservations
echo "Defining updated default network configuration..."
sudo virsh net-define static-network.xml

# Start the updated network
echo "Starting default network with static reservations..."
sudo virsh net-start default

# Enable autostart
echo "Enabling autostart for default network..."
sudo virsh net-autostart default

# Show the network configuration
echo "Network configuration updated successfully!"
echo ""
echo "Static IP reservations:"
echo "- ubuntu-dev:       192.168.122.10 (MAC: 52:54:00:12:34:10)"
echo "- ubuntu-gpu:       192.168.122.11 (MAC: 52:54:00:12:34:11)"
echo ""
echo "DHCP range for other VMs: 192.168.122.100-200"
echo ""
echo "Network status:"
sudo virsh net-list
