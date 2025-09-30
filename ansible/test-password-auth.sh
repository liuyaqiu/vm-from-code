#!/bin/bash
# Test script to verify password authentication is working

VM_IP="${1:-192.168.122.10}"
VM_NAME="${2:-ubuntu-dev}"

echo "=== Testing Password Authentication for $VM_NAME ==="
echo "IP: $VM_IP"
echo ""

echo "1. Testing SSH connection with password..."
echo "   (You should be prompted for password: vagrant)"
echo "   Command: ssh vagrant@$VM_IP"
echo ""

echo "2. Alternative test using sshpass (if available):"
if command -v sshpass >/dev/null 2>&1; then
    echo "   Testing automated password authentication..."
    sshpass -p vagrant ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@$VM_IP "echo 'Password authentication successful!'; hostname; whoami"
else
    echo "   sshpass not installed. Install with: sudo apt install sshpass"
    echo "   Then run: sshpass -p vagrant ssh vagrant@$VM_IP"
fi

echo ""
echo "3. Checking VM SSH configuration:"
echo "   Connect to VM and check: sudo cat /etc/ssh/sshd_config.d/50-vagrant-password-auth.conf"

echo ""
echo "4. Manual test:"
echo "   ssh vagrant@$VM_IP"
echo "   Password: vagrant"
echo ""
echo "If password authentication fails, check:"
echo "   - VM is running: sudo virsh list"
echo "   - Network connectivity: ping $VM_IP"
echo "   - SSH service: ssh vagrant@$VM_IP 'sudo systemctl status ssh'"
