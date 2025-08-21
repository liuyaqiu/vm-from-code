# Network Configuration Changes

## Problem Solved

The VirtualBox build was blocking due to no network interface being available inside the VM. This was caused by:

1. Packer cloud-init configuration not setting up any network interfaces
2. VirtualBox build process removing all netplan configurations
3. Ansible cloud-init having `network: config: disabled` which prevented network setup

## Solution Implemented

### 1. Enhanced Packer Cloud-Init Configuration

**File**: `packer/cloud-init/user-data`

Added basic network configuration that works for both QEMU and VirtualBox:

```yaml
network:
  version: 2
  ethernets:
    # For QEMU/libvirt (usually ens3, enp1s0, etc.)
    ens3:
      dhcp4: true
      optional: true
    enp1s0:
      dhcp4: true
      optional: true
    # For VirtualBox (usually enp0s3)
    enp0s3:
      dhcp4: true
      optional: true
    # Generic ethernet interface fallback
    eth0:
      dhcp4: true
      optional: true
```

This ensures that:
- Network interfaces are available during the build process
- Both QEMU and VirtualBox interface names are covered
- All interfaces are marked as `optional: true` to prevent boot failures

### 2. Updated VirtualBox Build Process

**File**: `packer/build-virtualbox.pkr.hcl`

- Added a file provisioner to copy the VirtualBox-specific netplan configuration
- Modified the cloud-init reset process to preserve basic networking
- Ensured netplan configuration is applied before completion

### 3. Smart Ansible Cloud-Init Configuration

**File**: `ansible/templates/user-data.j2`

Implemented conditional network configuration:

- **If `vm_static_ip` is defined**: Sets up static IP configuration for all common interface names
- **If no static IP**: Preserves the DHCP configuration from the base image by disabling cloud-init network management

This approach ensures:
- VMs with static IP requirements get proper network configuration
- VMs without static IP requirements use the working DHCP setup from the base image
- No conflicts between Packer and Ansible cloud-init configurations

## Testing the Configuration

### For VirtualBox DHCP (Default)

```bash
# Build the VirtualBox image
cd packer
make build-virtualbox

# Deploy with Ansible (without static IP)
cd ../ansible
# Make sure vm_static_ip is not set or is empty in your inventory
make create-vm VM_NAME=test-vm
```

### For Libvirt with Static IP

```bash
# Set static IP in inventory.yml
vm_static_ip: "192.168.122.50"

# Deploy with Ansible
make create-vm VM_NAME=test-vm
```

## Network Interface Names

The configuration handles these common interface naming patterns:

- **QEMU/Libvirt**: `ens3`, `enp1s0`
- **VirtualBox**: `enp0s3`
- **Generic**: `eth0`

All interfaces are marked as `optional: true` to prevent boot failures if the interface doesn't exist.

## Validation

After deployment, you can check network status:

```bash
# SSH into the VM
ssh vagrant@<VM_IP>

# Check network interfaces
ip addr show

# Check cloud-init status
sudo cloud-init status --long

# Check netplan configuration
sudo netplan get
```

## Benefits

1. **VirtualBox no longer blocks**: Network interface is always available
2. **Flexible deployment**: Supports both DHCP and static IP configurations
3. **Multi-platform compatibility**: Works with both QEMU and VirtualBox
4. **No conflicts**: Packer and Ansible cloud-init configurations work together
5. **Backwards compatible**: Existing deployments continue to work
