# Ansible libvirt VM Management

This directory contains Ansible playbooks for managing libvirt VMs with support for GPU passthrough.

## Features

- ✅ **Automated VM creation** from Packer-built images
- ✅ **GPU passthrough support** for hardware acceleration
- ✅ **VM lifecycle management** (start/stop/restart/destroy)
- ✅ **Network configuration** with multiple network options
- ✅ **Resource management** (CPU, memory, disk sizing)
- ✅ **QEMU/KVM optimization** with virtio drivers

## Quick Start

### 1. Install Dependencies

```bash
cd ansible
make install
```

### 2. Setup Environment

```bash
make setup
```

### 3. Create and Start a VM

```bash
# Create a basic development VM
make create VM=ubuntu-dev

# Create a VM with GPU passthrough (after GPU setup)
make create VM=ubuntu-gpu
```

### 4. Manage VMs

```bash
# List all VMs
make list

# Start a VM
make start VM=ubuntu-dev

# Stop a VM
make stop VM=ubuntu-dev

# Restart a VM
make restart VM=ubuntu-dev

# Destroy a VM
make destroy VM=ubuntu-dev
```

## VM Configuration

Edit `inventory.yml` to configure your VMs:

```yaml
vms:
  hosts:
    my-vm:
      vm_name: "my-vm"
      vm_memory: 4096        # RAM in MB
      vm_vcpus: 2           # Number of CPUs
      vm_disk_size: "40G"   # Disk size
      vm_network: "default"  # Network name
      gpu_passthrough: false # Enable GPU passthrough
```

## GPU Passthrough Setup

> **📋 For AMD Systems**: See the comprehensive [GPU-PASSTHROUGH-AMD.md](GPU-PASSTHROUGH-AMD.md) guide

### 1. Setup GPU Passthrough

```bash
make gpu-setup
```

### 2. Find Your GPU Device ID

```bash
lspci -nn | grep -i vga
# Example output: 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation [10de:2230]
```

### 3. Update GRUB Configuration

**For AMD Systems** (add to `/etc/default/grub`):
```bash
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt vfio-pci.ids=10de:2230"
```

**For Intel Systems** (add to `/etc/default/grub`):
```bash
GRUB_CMDLINE_LINUX="intel_iommu=on vfio-pci.ids=10de:2230"
```

### 4. Update GRUB and Reboot

```bash
sudo update-grub
sudo reboot
```

### 5. Update VM Configuration

Edit `inventory.yml`:
```yaml
ubuntu-gpu:
  gpu_passthrough: true
  gpu_device_id: "0000:01:00.0"  # Your GPU's PCI ID
```

### 6. Create GPU VM

```bash
make create VM=ubuntu-gpu
```

## VM Access

### VNC Access
```bash
virt-viewer vm-name
```

### SSH Access
```bash
ssh vagrant@<VM_IP>  # Password: vagrant
```

### Console Access
```bash
virsh console vm-name
```

## Network Configuration

Available networks are defined in `group_vars/all.yml`:

- **default**: Standard NAT network
- **isolated**: Isolated network for VM-to-VM communication

## Advanced Usage

### Custom VM Creation

```bash
ansible-playbook -i inventory.yml create-vm.yml \
  -e target_vm=my-custom-vm \
  -e vm_memory=8192 \
  -e vm_vcpus=4 \
  --ask-become-pass
```

### Bulk Operations

```bash
# Start all VMs
for vm in ubuntu-dev ubuntu-gpu; do
  make start VM=$vm
done
```

## Troubleshooting

### Check VM Status
```bash
make list
virsh list --all
```

### View VM Logs
```bash
virsh dominfo vm-name
journalctl -u libvirtd
```

### Check GPU Passthrough
```bash
lspci -k | grep -A 3 vga
dmesg | grep -i vfio
```

### Network Issues
```bash
virsh net-list --all
virsh net-info default
```

## File Structure

```
ansible/
├── Makefile              # Management commands
├── README.md            # This file
├── requirements.yml     # Ansible collections
├── inventory.yml        # VM definitions
├── group_vars/
│   └── all.yml         # Global variables
├── templates/
│   └── vm-config.xml.j2 # VM XML template
├── create-vm.yml        # VM creation playbook
├── destroy-vm.yml       # VM destruction playbook
├── manage-vm.yml        # VM management playbook
├── list-vms.yml         # VM listing playbook
└── setup-gpu-passthrough.yml # GPU setup playbook
```
