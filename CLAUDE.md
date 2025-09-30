# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project automates VM image creation and management using HashiCorp Packer for building Ubuntu 24.04 images and Ansible for deploying and managing libvirt/KVM VMs. The architecture separates build-time dependencies (Packer) from runtime environment management (Ansible).

## Build Commands

### Initial Setup
```bash
# 1. Install mise (if not already installed)
# See: https://mise.jdx.dev/getting-started.html

# 2. Install Python and uv via mise
mise install

# 3. Install Python dependencies (Ansible)
mise run install-deps
# OR use the Makefile
make ansible-install

# 4. Complete setup
make setup          # Complete setup: installs Packer, QEMU/KVM, Ansible collections, initializes plugins
make install        # Install build dependencies (Packer) only
```

### Building Images
```bash
make build                    # Build libvirt/KVM image (default)
make packer-build-libvirt     # Build libvirt image explicitly
make packer-validate          # Validate Packer configuration
```

### VM Management with Ansible
```bash
make ansible-create target_vm=ubuntu-dev    # Create and start VM
make ansible-destroy target_vm=ubuntu-dev   # Destroy VM
make ansible-list                                  # List all VMs
```

### Cleaning
```bash
make clean              # Clean all artifacts (packer + ansible)
cd packer && make clean # Clean only packer artifacts
cd ansible && make clean # Clean only ansible artifacts
```

## Architecture

### Two-Phase Workflow

**Phase 1: Packer Image Building** (`packer/`)
- Downloads Ubuntu 24.04 cloud image
- Uses QEMU/KVM to create base VM
- Provisions with cloud-init (creates `vagrant` user with passwordless sudo)
- Installs base packages via `scripts/provision.sh`
- **Resets cloud-init state** for deployment flexibility
- Outputs clean qcow2 image to `builds/ubuntu-24.04-libvirt.qcow2`

**Phase 2: Ansible VM Deployment** (`ansible/`)
- Copies base image to libvirt directory
- Creates VM-specific disk from base image (copy-on-write)
- Applies deployment-specific cloud-init configuration (hostname, network, packages)
- Manages VM lifecycle (start/stop/destroy)

### Key Design Decision: Cloud-init State Reset

The Packer build process **resets cloud-init state** after provisioning, which means:
- Base image can be reused for multiple deployments
- Each VM gets fresh cloud-init run with deployment-specific configuration
- Network configuration is applied at deployment time, not build time
- See `packer/ubuntu-24.04.pkr.hcl` lines 121-131 for reset logic

## File Structure

```
vm-from-code/
├── Makefile                     # Root orchestrator (delegates to packer/ansible)
├── packer/                      # Image building
│   ├── Makefile
│   ├── ubuntu-24.04.pkr.hcl    # Main Packer config (QEMU source, build steps)
│   ├── cloud-init/             # Build-time cloud-init
│   │   ├── user-data           # Creates vagrant user, installs SSH keys
│   │   └── meta-data           # Instance metadata
│   ├── scripts/
│   │   ├── provision.sh        # Install packages (curl, git, vim, etc.)
│   │   └── cleanup.sh          # System cleanup, reset cloud-init
│   └── CLOUD-INIT-WORKFLOW.md  # Cloud-init architecture docs
├── ansible/                     # VM deployment & management
│   ├── Makefile
│   ├── inventory.yml            # VM definitions (memory, CPU, network, GPU config)
│   ├── group_vars/all.yml       # Default settings, paths
│   ├── templates/
│   │   ├── vm-config.xml.j2    # Libvirt domain XML
│   │   ├── user-data.j2        # Deployment cloud-init config
│   │   └── meta-data.j2        # Deployment metadata
│   ├── create-vm.yml            # Main VM creation playbook
│   ├── destroy-vm.yml           # VM destruction playbook
│   ├── manage-vm.yml            # Start/stop/restart operations
│   └── setup-gpu-passthrough.yml # GPU passthrough setup
├── builds/                      # Output directory (qcow2 images)
├── secrets/                     # SSH keys for VMs
└── scripts/
    └── install-packer.sh        # Auto-install Packer script
```

## Network Configuration

### Static IP Assignment
Configured in `ansible/inventory.yml` per VM:
```yaml
vm_static_ip: "192.168.122.30"
vm_gateway: "192.168.122.1"
vm_dns: ["192.168.122.1", "8.8.8.8"]
vm_mac_address: "52:54:00:12:34:30"  # For static DHCP reservation
```

### Network Setup Flow
1. Packer build: Creates base networking via cloud-init (DHCP on common interfaces)
2. Packer cleanup: Removes netplan config, resets cloud-init state
3. Ansible deployment: Applies VM-specific network config via `templates/user-data.j2`

See [NETWORK-CONFIGURATION.md](NETWORK-CONFIGURATION.md) for detailed network architecture.

## GPU Passthrough

The project supports NVIDIA and AMD GPU passthrough for VMs:

1. Configure IOMMU in GRUB (`/etc/default/grub`)
2. Bind GPU to vfio-pci driver
3. Set `gpu_passthrough: true` and `gpu_device_id` in `ansible/inventory.yml`
4. Run `make ansible-create target_vm=ubuntu-gpu`

See `ansible/NVIDIA-GPU-PASSTHROUGH-GUIDE.md` for detailed setup.

## Customization Points

### Adding Packages to Base Image
Edit `packer/scripts/provision.sh`:
```bash
sudo apt-get install -y \
    your-package-here \
    another-package
```

### VM-Specific Packages
Configure in `ansible/inventory.yml`:
```yaml
vm_packages: ["htop", "docker.io", "nginx"]
```
These are installed during Ansible deployment via cloud-init.

### Modifying VM Resources
Edit `ansible/inventory.yml`:
```yaml
vm_memory: 4096      # RAM in MB
vm_vcpus: 4          # CPU cores
vm_disk_size: "80G"  # Disk size
```

### Cloud-init Configuration
- **Build-time**: `packer/cloud-init/user-data` (base user setup)
- **Deploy-time**: `ansible/templates/user-data.j2` (VM-specific config)

## Authentication

Default credentials for all VMs:
- **Username**: `vagrant`
- **Password**: `vagrant`
- **SSH Key**: Auto-generated in `secrets/libvirt_vms_ed25519` (created during ansible setup)

Access VMs:
```bash
# Using SSH key
ssh -i secrets/libvirt_vms_ed25519 vagrant@192.168.122.30

# Using password
ssh vagrant@192.168.122.30

# Using Ansible Makefile
cd ansible && make ssh VM=ubuntu-dev
```

## Troubleshooting

### Build hangs during cloud-init
- Increase `ssh_timeout` in `packer/ubuntu-24.04.pkr.hcl` (currently 20m)
- Check virtualization is enabled: `egrep -c '(vmx|svm)' /proc/cpuinfo` (should be > 0)
- Run with `headless = false` to see VM console

### VM not getting IP address
- Check network is started: `sudo virsh net-list`
- Verify MAC address is unique in `ansible/inventory.yml`
- Check cloud-init logs in VM: `sudo cloud-init status --long`

### Packer not found
- Run `make install` or `make setup` to auto-install Packer
- Manual install: `scripts/install-packer.sh`

### Ansible playbook fails
- Ensure libvirt is running: `sudo systemctl status libvirtd`
- Check permissions: Ansible needs sudo access
- Verify base image exists: `ls -lh builds/ubuntu-24.04-libvirt.qcow2`

### Ansible not found
- Install Python dependencies via mise: `mise run install-deps` or `make ansible-install`
- Verify mise is installed: `mise --version`
- Ensure you're in the mise environment: `mise activate` or use `mise exec` prefix

## Important Notes

- **Python environment**: This project uses `mise` to manage Python and dependencies. Ansible is installed via `uv` in a virtual environment (`.venv`)
- **Base image reuse**: The Packer-built image can be used for multiple VMs (copy-on-write)
- **Cloud-init runs twice**: Once during Packer build (user setup), once during Ansible deployment (network/hostname)
- **No Vagrant**: Despite the `vagrant` user, this project doesn't use Vagrant - it's raw libvirt/KVM
- **GPU VMs require reboot**: After running `make ansible-gpu-setup`, reboot host before creating GPU VMs