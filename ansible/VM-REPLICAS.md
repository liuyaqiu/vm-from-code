# VM Replicas Feature

This document describes the VM replica functionality that allows you to create multiple identical VMs with a single configuration.

## Overview

The VM replica feature enables you to:
- Define a single VM configuration in `inventory.yml`
- Automatically create multiple VMs with the same specifications
- Only vary the MAC address and static IP for each replica
- Manage all replicas with simple commands

## Configuration

### Basic Replica Configuration

To enable replicas, add the following fields to your VM definition in `ansible/inventory.yml`:

```yaml
vms:
  hosts:
    ubuntu-dev:
      vm_name: "ubuntu-dev"
      vm_hostname: "ubuntu-dev"
      vm_memory: 4096
      vm_vcpus: 2
      vm_disk_size: "40G"
      # ... other common settings ...

      # Replica configuration
      replicas: 3  # Number of VM instances to create
      vm_mac_addresses:
        - "52:54:00:12:34:10"
        - "52:54:00:12:34:11"
        - "52:54:00:12:34:12"
      vm_static_ips:
        - "192.168.88.10"
        - "192.168.88.11"
        - "192.168.88.12"
```

### Important Notes

1. **Array Lengths**: The number of MAC addresses and static IPs must match the `replicas` value
2. **VM Naming**: VMs will be named as `{base_name}-{index}`:
   - `ubuntu-dev-0`
   - `ubuntu-dev-1`
   - `ubuntu-dev-2`
3. **Single VM Mode**: If `replicas` is set to 1 or omitted, the VM name remains unchanged (no `-0` suffix)
4. **Shared Configuration**: All replicas share the same:
   - Memory allocation
   - CPU count
   - Disk size
   - Packages
   - Docker/NVIDIA installation settings
   - Shared folders
   - GPU passthrough settings (if applicable)

## Usage

### Creating VM Replicas

```bash
# Create all replicas for ubuntu-dev
cd ansible
make create VM=ubuntu-dev --ask-become-pass
```

This will create:
- `ubuntu-dev-0` with IP 192.168.88.10
- `ubuntu-dev-1` with IP 192.168.88.11
- `ubuntu-dev-2` with IP 192.168.88.12

### SSH into Replicas

#### Using SSH Key Authentication

```bash
# Without replica index - shows available replicas
make ssh VM=ubuntu-dev

# With replica index - connects directly
make ssh VM=ubuntu-dev@0  # Connect to ubuntu-dev-0
make ssh VM=ubuntu-dev@1  # Connect to ubuntu-dev-1
make ssh VM=ubuntu-dev@2  # Connect to ubuntu-dev-2
```

#### Using Password Authentication

```bash
make ssh-pass VM=ubuntu-dev@0  # Password: vagrant
make ssh-pass VM=ubuntu-dev@1
```

### Destroying VM Replicas

```bash
# Destroys all replicas
make destroy VM=ubuntu-dev
```

This will prompt for confirmation, then destroy:
- `ubuntu-dev-0`
- `ubuntu-dev-1`
- `ubuntu-dev-2`

### Listing VMs

```bash
make list
```

Shows all VMs including replicas with their status.

## Use Cases

### Development Cluster

Create a small cluster for distributed application testing:

```yaml
dev-cluster:
  vm_name: "dev-node"
  replicas: 3
  vm_memory: 2048
  vm_vcpus: 2
  vm_mac_addresses:
    - "52:54:00:13:00:01"
    - "52:54:00:13:00:02"
    - "52:54:00:13:00:03"
  vm_static_ips:
    - "192.168.88.20"
    - "192.168.88.21"
    - "192.168.88.22"
  install_docker: true
```

### Testing Environment

Create multiple identical VMs for parallel testing:

```yaml
test-env:
  vm_name: "test-vm"
  replicas: 5
  vm_memory: 4096
  vm_vcpus: 2
  vm_mac_addresses:
    - "52:54:00:14:00:01"
    - "52:54:00:14:00:02"
    - "52:54:00:14:00:03"
    - "52:54:00:14:00:04"
    - "52:54:00:14:00:05"
  vm_static_ips:
    - "192.168.88.30"
    - "192.168.88.31"
    - "192.168.88.32"
    - "192.168.88.33"
    - "192.168.88.34"
```

## Implementation Details

### Playbook Structure

The replica feature uses the following playbooks:

1. **create-vm-replicas.yml**: Main playbook that processes replica configuration
2. **create-single-vm.yml**: Task file that creates individual VMs
3. **destroy-vm-replicas.yml**: Destroys all replicas
4. **destroy-single-vm.yml**: Task file that destroys individual VMs

### Template Variables

Templates support both single VM and replica modes through the `replica_config` variable:

```jinja2
{% set config = replica_config | default(vm_config) %}
<name>{{ config.vm_name }}</name>
```

This allows backward compatibility with existing single-VM configurations.

### Network Configuration

Each replica gets:
- Unique MAC address from `vm_mac_addresses` array
- Unique static IP from `vm_static_ips` array
- Same network bridge or libvirt network as configured

## Validation

The playbook validates:
- Replica count > 0
- MAC addresses count = replicas count
- Static IPs count = replicas count

If validation fails, the playbook will stop with an error message.

## Backward Compatibility

The replica feature is fully backward compatible:
- VMs without `replicas` field work as before
- VMs with `replicas: 1` behave like single VMs (no `-0` suffix)
- Existing single-VM configurations don't need modification

## Troubleshooting

### VM Creation Fails

1. **Check array lengths**: Ensure `vm_mac_addresses` and `vm_static_ips` have exactly `replicas` entries
2. **Verify MAC addresses**: Each MAC must be unique across all VMs
3. **Check IP conflicts**: Ensure IPs don't conflict with existing VMs or network devices

### SSH Connection Issues

1. **Wrong replica index**: Check available replicas with `make ssh VM=ubuntu-dev` (without @index)
2. **IP not responding**: Verify VM is running with `make list`
3. **SSH key missing**: Run `make setup` to generate SSH keys

### Network Issues

1. **Bridge not configured**: Ensure bridge network is set up if using `vm_bridge`
2. **IP conflicts**: Check for IP address conflicts on your network
3. **Firewall blocking**: Verify firewall rules allow VM traffic

## Future Enhancements

Potential future improvements:
- Auto-generate MAC addresses
- Auto-allocate IPs from CIDR range
- Per-replica customization (e.g., different disk sizes)
- Load balancer configuration for replicas
- Ansible inventory generation for replicas
