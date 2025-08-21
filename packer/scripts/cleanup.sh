#!/bin/bash
set -e

echo "=== Starting cleanup ==="
echo "NOTE: Cloud-init state has already been reset by previous provisioner"

# Clean package cache
echo "Cleaning package cache..."
sudo apt-get autoremove -y
sudo apt-get autoclean
sudo apt-get clean

# Remove temporary files
echo "Removing temporary files..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clear log files
echo "Clearing log files..."
sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
sudo find /var/log -type f -name "*.1" -delete
sudo find /var/log -type f -name "*.gz" -delete

# Clear systemd journal logs
echo "Clearing systemd journal logs..."
sudo journalctl --vacuum-time=1s
sudo journalctl --vacuum-size=1M

# Clear additional system logs and caches
echo "Clearing additional system artifacts..."
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /var/cache/debconf/*
sudo rm -rf /var/lib/dhcp/*

# Remove vagrant user completely
echo "Removing vagrant user and home directory..."
sudo userdel -r vagrant 2>/dev/null || true

# Clear bash history
echo "Clearing bash history..."
history -c
sudo rm -f /root/.bash_history

# Clear machine-id
echo "Clearing machine-id..."
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Reset SSH host keys for security
echo "Regenerating SSH host keys..."
sudo rm -f /etc/ssh/ssh_host_*
sudo ssh-keygen -A

# Clear network configuration
echo "Clearing network configuration..."
sudo rm -f /etc/udev/rules.d/70-persistent-net.rules

# Remove sudoers entries for vagrant user
echo "Cleaning sudoers configuration..."
sudo rm -f /etc/sudoers.d/vagrant

# Clear any remaining user-specific artifacts
echo "Clearing remaining user artifacts..."
sudo rm -rf /var/mail/vagrant
sudo rm -rf /var/spool/mail/vagrant

# Zero out free space for better compression
echo "Zeroing out free space..."
sudo dd if=/dev/zero of=/EMPTY bs=1M || true
sudo rm -f /EMPTY

# Sync filesystem
echo "Syncing filesystem..."
sync

echo "=== Cleanup completed ==="
