#!/bin/bash

# Script to verify that 50-cloud-init.yaml is properly deleted and static IP is configured

echo "=== Verifying Network Configuration Cleanup ==="

# Variables (update the IP to match your VM)
VM_IP="${1:-192.168.122.30}"
VM_USER="vagrant"
VM_PASS="vagrant"

echo "Testing VM: $VM_IP"
echo "User: $VM_USER"
echo ""

# Function to run SSH command with password
run_ssh_cmd() {
    local cmd="$1"
    echo "Running: $cmd"
    sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 "$VM_USER@$VM_IP" "$cmd"
    echo ""
}

echo "1. Checking if 50-cloud-init.yaml exists (should be GONE):"
run_ssh_cmd "sudo ls -la /etc/netplan/ | grep cloud-init || echo 'No cloud-init files found - GOOD!'"

echo "2. Checking our static configuration (should exist):"
run_ssh_cmd "sudo ls -la /etc/netplan/99-static-ip.yaml"

echo "3. Showing active netplan configuration:"
run_ssh_cmd "sudo cat /etc/netplan/*.yaml"

echo "4. Checking current IP address:"
run_ssh_cmd "ip addr show | grep 'inet ' | grep -v '127.0.0.1'"

echo "5. Checking network fix service status:"
run_ssh_cmd "sudo systemctl status fix-network-final.service"

echo "6. Checking network fix logs:"
run_ssh_cmd "sudo cat /var/log/fix-network-final.log"

echo "7. Testing network connectivity:"
run_ssh_cmd "ping -c 3 8.8.8.8"

echo "=== Verification Complete ==="
echo ""
echo "✅ SUCCESS CRITERIA:"
echo "- NO 50-cloud-init.yaml file should exist"
echo "- 99-static-ip.yaml should exist with static configuration"
echo "- fix-network-final.service should have run successfully"
echo "- /var/log/fix-network-final.log should show successful cleanup"
echo "- VM should have the correct static IP ($VM_IP)"
echo "- Network connectivity should work"
