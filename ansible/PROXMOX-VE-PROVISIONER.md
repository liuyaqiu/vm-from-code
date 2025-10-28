# Proxmox VE Provisioner Guide

This guide explains how to use the Proxmox VE (PVE) provisioner to create and manage VMs on a remote Proxmox VE node.

## Overview

The PVE provisioner extends the existing VM automation to support **remote Proxmox VE nodes** in addition to local libvirt/KVM. Key features:

- ✅ **Same base image**: Reuses the Packer-built Ubuntu 24.04 qcow2 image
- ✅ **Replica support**: Full support for creating multiple VM instances
- ✅ **Static networking**: MAC address and IP configuration
- ✅ **Post-deployment**: Same NVIDIA, Docker, custom package support
- ✅ **Cloud-init**: Native PVE cloud-init integration (no ISO needed!)
- ✅ **Auto-detection**: Makefile automatically routes to correct provisioner

## Architecture

### Provisioner Selection

VMs are configured with a `provisioner` field in `inventory.yml`:

```yaml
# Libvirt VM (local KVM)
k8s-master:
  provisioner: libvirt
  vm_name: "k8s-master"
  # ... libvirt-specific config ...

# PVE VM (remote Proxmox)
k8s-master-pve:
  provisioner: pve
  pve_node: "pve"
  pve_storage: "local-lvm"
  pve_vmid_start: 200
  vm_name: "k8s-master"
  # ... same VM config as libvirt ...
```

### Network Configuration

**PVE Bridge**: Uses `vmbr0` (managed by Proxmox)
- No manual bridge setup needed
- PVE handles bridge networking automatically
- Static MAC addresses assigned via `vm_mac_addresses`
- Static IPs configured via cloud-init

**Libvirt Bridge**: Uses `br0` (created by netplan)
- Requires manual bridge setup in `setup.yml`
- Attaches to physical interface

## Prerequisites

### 1. PVE API Token

Create an API token on your Proxmox VE node:

1. Log into PVE web UI: `https://192.168.88.4:8006/`
2. Navigate to: **Datacenter → Permissions → API Tokens**
3. Click **Add**
4. Configure:
   - **User**: `root@pam` (or create dedicated user)
   - **Token ID**: `ansible-automation`
   - **Privilege Separation**: Uncheck (to inherit all permissions)
5. **Save the secret** - it won't be shown again!

### 2. Configure PVE Credentials

The credentials are stored in `ansible/group_vars/pve.yml` (encrypted with ansible-vault):

```yaml
---
pve_api_host: "192.168.88.4"
pve_api_user: "root@pam"
pve_api_token_id: "ansible-automation"
pve_api_token_secret: "your-secret-token-here"
pve_node: "pve"  # Your PVE node name
```

**Encrypt the file:**
```bash
cd ansible
ansible-vault encrypt group_vars/pve.yml
```

**Edit encrypted file:**
```bash
ansible-vault edit group_vars/pve.yml
```

### 3. Install Python Dependencies

The PVE provisioner requires `proxmoxer`:

```bash
pip3 install proxmoxer requests
```

Or it will be installed automatically during `make setup-pve`.

## Quick Start

### Step 1: Build Base Image

```bash
# From project root
make build
```

This creates `builds/ubuntu-24.04-libvirt.qcow2` (works for both libvirt and PVE).

### Step 2: Setup PVE Environment

```bash
cd ansible
make setup-pve
```

This will:
1. Verify PVE API connectivity
2. Upload the base qcow2 image to `/var/lib/vz/template/qcow/` on PVE node
3. Prepare environment for VM creation

**Note**: You'll be prompted for the ansible-vault password.

### Step 3: Create VMs

```bash
# Single VM
make create VM=k8s-master-pve

# All VMs defined in inventory
make create VM=k8s-master-pve
make create VM=k8s-etcd-pve
make create VM=k8s-worker-pve
```

The Makefile automatically detects the `provisioner` field and routes to the correct playbook.

### Step 4: Access VMs

```bash
# SSH to first replica
make ssh VM=k8s-master-pve@0

# SSH to second replica
make ssh VM=k8s-master-pve@1

# Using password
make ssh-pass VM=k8s-master-pve@0
```

## Configuration Reference

### Required PVE Fields

```yaml
k8s-master-pve:
  provisioner: pve                # REQUIRED: Set to 'pve'
  pve_node: "pve"                 # REQUIRED: PVE node name
  pve_storage: "local-lvm"        # REQUIRED: Storage backend
  pve_vmid_start: 200             # REQUIRED: Starting VMID (100-999999)
```

### Common Fields (Same as Libvirt)

```yaml
  vm_name: "k8s-master"           # Base VM name
  vm_hostname: "k8s-master"       # Hostname prefix
  vm_memory: 4096                 # RAM in MB
  vm_vcpus: 2                     # CPU cores
  vm_disk_size: "40G"             # Disk size
  vm_autostart: true              # Start on PVE boot

  # Replica configuration
  replicas: 3
  vm_mac_addresses:
    - "52:54:00:88:00:10"
    - "52:54:00:88:00:11"
    - "52:54:00:88:00:12"
  vm_static_ips:
    - "192.168.88.10"
    - "192.168.88.11"
    - "192.168.88.12"

  # Post-deployment (same as libvirt)
  install_docker: true
  install_nvidia: false
  custom_packages: [...]
  post_install_script: "scripts/post-install.sh"
```

### VMID Assignment

VMIDs are assigned sequentially for replicas:

```yaml
pve_vmid_start: 200
replicas: 3

# Results in:
# k8s-master-0 -> VMID 200
# k8s-master-1 -> VMID 201
# k8s-master-2 -> VMID 202
```

**VMID ranges:**
- `100-199`: Reserved for single VMs or first set
- `200-299`: Master node replicas
- `300-399`: ETCD node replicas
- `400-499`: Worker node replicas

Adjust `pve_vmid_start` to avoid conflicts.

## PVE Storage Options

Common PVE storage backends:

| Storage | Type | Use Case |
|---------|------|----------|
| `local` | Directory | VM configs, ISOs, templates |
| `local-lvm` | LVM-Thin | VM disks (recommended) |
| `local-zfs` | ZFS | VM disks with snapshots |
| `nfs-storage` | NFS | Shared storage across nodes |

**Check available storage:**
```bash
pvesm status
```

Update `pve_storage` in inventory to match your PVE setup.

## Cloud-Init Configuration

PVE has **native cloud-init support** - no ISO creation needed!

The playbook configures:
- **User**: `vagrant` with password `vagrant`
- **SSH keys**: Automatically from `secrets/libvirt_vms_ed25519.pub`
- **Network**: Static IP via `ipconfig0` parameter
- **Hostname**: Set per replica
- **Packages**: Installed via cloud-init `packages` directive

Cloud-init data is injected directly by PVE (cleaner than libvirt's ISO method).

## Comparison: Libvirt vs PVE

| Feature | Libvirt | PVE |
|---------|---------|-----|
| **Location** | Local KVM/QEMU | Remote Proxmox node |
| **VM Definition** | XML template | API parameters |
| **Network** | Custom bridge (`br0`) | PVE-managed (`vmbr0`) |
| **Cloud-init** | ISO file (NoCloud) | Native drive-based |
| **Disk Import** | qcow2 copy | `import-from` parameter |
| **Post-deploy** | ✅ Same | ✅ Same |
| **Replicas** | ✅ Supported | ✅ Supported |
| **Authentication** | sudo password | API token |

## Troubleshooting

### Connection Issues

**Problem**: `ansible-playbook` fails to connect to PVE

**Solution**:
1. Verify PVE is reachable: `ping 192.168.88.4`
2. Check API token is valid in PVE web UI
3. Verify `group_vars/pve.yml` has correct credentials
4. Test API manually:
   ```bash
   curl -k -H "Authorization: PVEAPIToken=root@pam!ansible-automation=YOUR-SECRET" \
     https://192.168.88.4:8006/api2/json/version
   ```

### Image Upload Fails

**Problem**: `setup-pve.yml` fails to upload image

**Solution**:
1. Ensure base image exists: `ls -lh ../builds/ubuntu-24.04-libvirt.qcow2`
2. Check SSH access to PVE node: `ssh root@192.168.88.4`
3. Verify disk space on PVE: `df -h /var/lib/vz/template/qcow/`
4. Force re-upload: `make setup-pve -e force_upload=true`

### VM Creation Fails

**Problem**: VM creation fails with "VMID already exists"

**Solution**:
1. Check existing VMs in PVE: `qm list`
2. Either destroy existing VM or change `pve_vmid_start` in inventory
3. Destroy via Ansible: `make destroy VM=k8s-master-pve`

**Problem**: "Storage not found"

**Solution**:
1. List available storage: `pvesm status`
2. Update `pve_storage` in inventory.yml to match your PVE setup

### Cloud-init Not Running

**Problem**: VM boots but has no network/wrong hostname

**Solution**:
1. Check cloud-init status on VM: `ssh vagrant@<ip> sudo cloud-init status`
2. View cloud-init logs: `sudo cloud-init collect-logs`
3. Verify PVE cloud-init drive is attached: Check VM hardware in PVE UI
4. Regenerate cloud-init: `qm cloudinit update <vmid>` (on PVE node)

## Advanced Usage

### Custom Storage

Use different storage for different VMs:

```yaml
k8s-master-pve:
  pve_storage: "local-lvm"  # Fast local storage

k8s-worker-pve:
  pve_storage: "nfs-storage"  # Shared storage for migration
```

### Mixed Provisioners

Run some VMs locally, others on PVE:

```yaml
# Local development
k8s-master:
  provisioner: libvirt
  replicas: 1

# Production on PVE
k8s-master-pve:
  provisioner: pve
  replicas: 3
```

Same base image, same playbooks, different infrastructure!

### Multiple PVE Nodes

To support multiple PVE nodes, create separate inventory groups:

```yaml
k8s-master-pve1:
  provisioner: pve
  pve_node: "pve1"
  pve_vmid_start: 200

k8s-master-pve2:
  provisioner: pve
  pve_node: "pve2"
  pve_vmid_start: 300
```

## Makefile Commands Reference

| Command | Description |
|---------|-------------|
| `make setup-pve` | Setup PVE environment and upload base image |
| `make create VM=<name>` | Create VM(s) - auto-detects provisioner |
| `make destroy VM=<name>` | Destroy VM(s) - auto-detects provisioner |
| `make ssh VM=<name>@<idx>` | SSH to VM replica (works for both provisioners) |
| `make ssh-pass VM=<name>@<idx>` | SSH with password |

## Implementation Files

| File | Purpose |
|------|---------|
| [setup-pve.yml](setup-pve.yml) | Setup PVE and upload base image |
| [create-vm-replicas-pve.yml](create-vm-replicas-pve.yml) | Create VM replicas on PVE |
| [create-single-vm-pve.yml](create-single-vm-pve.yml) | Create single VM on PVE (task file) |
| [destroy-vm-replicas-pve.yml](destroy-vm-replicas-pve.yml) | Destroy VM replicas on PVE |
| [destroy-single-vm-pve.yml](destroy-single-vm-pve.yml) | Destroy single VM on PVE (task file) |
| [group_vars/pve.yml](group_vars/pve.yml) | PVE credentials (encrypted) |
| [inventory.yml](inventory.yml) | VM definitions with provisioner field |

## See Also

- [CLAUDE.md](../CLAUDE.md) - Project overview
- [NETWORK-CONFIGURATION.md](../NETWORK-CONFIGURATION.md) - Network architecture
- [GPU-PASSTHROUGH-AMD.md](GPU-PASSTHROUGH-AMD.md) - GPU passthrough for libvirt
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Ansible Proxmox Modules](https://docs.ansible.com/ansible/latest/collections/community/proxmox/)
