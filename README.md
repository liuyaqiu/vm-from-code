# Ubuntu 24.04 VM Images with Packer

This project uses HashiCorp Packer to create VM images based on Ubuntu 24.04 LTS Server with pre-installed development tools. It supports **libvirt/KVM** provider.

## Features

### Base System
- Ubuntu 24.04 LTS Server
- 40GB disk space
- 2GB RAM
- 2 CPU cores

### Pre-installed Packages
- `curl` - Command line tool for transferring data
- `wget` - Network downloader
- `vim` - Text editor
- `git` - Version control system
- `net-tools` - Network utilities (netstat, etc.)
- `iputils-ping` - Ping utility
- `openssh-server` - SSH server
- `build-essential` - Compilation tools

### User Configuration
- Username: `vagrant`
- Password: `vagrant`
- Passwordless sudo configured
- SSH key authentication enabled

### Supported Providers
- **libvirt/KVM** - Raw qcow2 image for direct use with libvirt/virsh

## Prerequisites

**No manual installation required!** This project automatically installs all dependencies.

### Dependency Management
- **Build Dependencies** (Packer) - *Auto-installed*
- **Runtime Dependencies** (QEMU/KVM, libvirt) - *Managed by Ansible*

The project uses a clean separation of concerns:
- **Packer**: Handles VM image building (build-time dependencies)
- **Ansible**: Manages runtime environment and VM lifecycle (runtime dependencies)

This architecture ensures:
- ✅ **Clean separation**: Build tools vs runtime environment
- ✅ **Infrastructure as Code**: All dependencies managed via Ansible
- ✅ **Flexibility**: Easy to customize runtime environment per host
- ✅ **Scalability**: Ansible can manage multiple hosts



## Quick Start

1. **Clone this project**
   ```bash
   git clone <repository-url>
   cd vm-from-code
   ```

2. **One-command setup** (installs everything automatically)
   ```bash
   make setup
   ```

3. **Build VM image**
   ```bash
   make build
   ```

**That's it!** The project automatically:
- Installs Packer (build dependency)
- Installs QEMU/KVM and libvirt via Ansible (runtime dependencies)
- Initializes Packer plugins
- Validates configuration
- Builds the libvirt image

### Alternative Commands

For step-by-step control:

```bash
# Install build dependencies only (Packer)
make install

# Install runtime dependencies only (QEMU/KVM via Ansible)
make ansible-setup

# Initialize Packer (auto-installs Packer if needed)
make packer-init

# Validate configuration
make packer-validate

# Build libvirt image
make packer-build-libvirt
```

   The build process will:
   - Download Ubuntu 24.04 cloud image
   - Create VM using QEMU/KVM
   - Configure with cloud-init
   - Install required packages
   - Configure the vagrant user
   - Clean up the system
   - Export as raw qcow2 image (libvirt)

5. **Use the images**
   
   **libvirt (Raw Image):**
   ```bash
   # Copy image to libvirt directory
   sudo cp builds/ubuntu-24.04-libvirt.qcow2 /var/lib/libvirt/images/
   
   # Create VM with virt-install
   sudo virt-install \
     --name ubuntu-24-04-server \
     --ram 2048 \
     --vcpus 2 \
     --disk path=/var/lib/libvirt/images/ubuntu-24.04-libvirt.qcow2,format=qcow2 \
     --import \
     --network bridge=virbr0 \
     --graphics spice \
     --noautoconsole
   
   # Or create VM with virsh XML (see examples below)
   ```

## Build Process Details

### Timeline
The complete setup and build process typically takes:
- **First run**: 5-10 minutes (includes dependency installation via Ansible)
- **Subsequent builds**: 3-5 minutes

Time depends on:
- Internet connection speed (for downloading Packer and cloud image)
- System performance
- Ansible playbook execution (for QEMU/KVM setup)

### Build Steps
1. **Build Dependencies** - Auto-installs Packer if needed
2. **Runtime Dependencies** - Ansible installs QEMU/KVM, libvirt if needed
3. **Plugin Initialization** - Initializes Packer plugins
4. **Download Cloud Image** - Downloads Ubuntu 24.04 cloud image
5. **VM Creation** - Creates QEMU VM with specified resources
6. **Cloud-init Configuration** - Configures system using cloud-init
7. **Package Installation** - Installs required development tools
8. **User Configuration** - Sets up vagrant user and SSH keys
9. **System Cleanup** - Removes temporary files and optimizes for distribution
10. **Image Export** - Exports as qcow2 image file

### Output
- **libvirt Image**: `builds/ubuntu-24.04-libvirt.qcow2`
- **Build Logs**: Console output with detailed progress
- **Temporary Files**: `output/qemu/` (can be deleted after build)

## Customization

### Modifying Variables
Edit `packer/variables.pkrvars.hcl` to customize:
- VM resources (RAM, CPU, disk)
- Ubuntu ISO version
- VM name

### Adding Packages
Edit `packer/scripts/provision.sh` to install additional packages:
```bash
sudo apt-get install -y \
    your-package-here \
    another-package
```

### Custom Configuration
- **System cleanup**: Modify `packer/scripts/cleanup.sh`
- **Cloud-init config**: Edit `packer/cloud-init/user-data`

## Troubleshooting

### Common Issues

1. **Cloud image download fails**
   ```
   Error downloading cloud image
   ```
   - Check internet connection
   - Verify cloud image URL in variables file
   - Cloud image checksum mismatch - update checksum in variables

3. **Build hangs during cloud-init**
   - Increase `ssh_timeout` in configuration
   - Check VT-x/AMD-V virtualization is enabled
   - Ensure sufficient disk space
   - Verify cloud-init configuration syntax

4. **SSH connection fails**
   ```
   Timeout waiting for SSH
   ```
   - Check VM networking settings
   - Verify cloud-init configuration
   - Check if VM actually boots (enable GUI mode)

### Debug Mode
Enable headless=false in the configuration to see the VM during build:
```hcl
headless = false
```

### Clean Build
Remove temporary files between builds:
```bash
make clean
```

Or clean specific components:
```bash
cd packer && make clean  # Clean packer artifacts only
cd ansible && make clean # Clean ansible artifacts only
```

## File Structure

```
vm-from-code/
├── packer/                   # Packer configuration and related files
│   ├── ubuntu-24.04.pkr.hcl # Main Packer configuration
│   ├── variables.pkrvars.hcl # Build variables
│   ├── cloud-init/          # Cloud-init configuration files
│   │   ├── user-data        # Cloud-init user configuration
│   │   └── meta-data        # Instance metadata
│   ├── scripts/             # Provisioning scripts
│   │   ├── provision.sh     # Package installation

│   │   └── cleanup.sh       # System cleanup
│   ├── CLOUD-IMAGE-MIGRATION.md
│   └── CLOUD-INIT-WORKFLOW.md
├── ansible/                  # Ansible automation for VM management
│   ├── create-vm.yml         # Create and configure VMs
│   ├── destroy-vm.yml        # Destroy VMs
│   ├── group_vars/all.yml    # Default variables
│   ├── inventory.yml         # VM inventory
│   └── templates/            # Jinja2 templates

├── builds/                   # Output directory for built images
├── secrets/                  # SSH keys and certificates
├── Makefile                  # Root Makefile (delegates to all tools)
└── README.md                 # This file
```

## Using the libvirt Image

### virt-install Examples

**Basic VM Creation:**
```bash
sudo virt-install \
  --name ubuntu-24-04-server \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/ubuntu-24.04-libvirt.qcow2,format=qcow2 \
  --import \
  --network bridge=virbr0 \
  --graphics spice \
  --noautoconsole
```

**Headless VM (no graphics):**
```bash
sudo virt-install \
  --name ubuntu-24-04-headless \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/ubuntu-24.04-libvirt.qcow2,format=qcow2 \
  --import \
  --network bridge=virbr0 \
  --graphics none \
  --console pty,target_type=serial \
  --noautoconsole
```

### virsh Management

```bash
# Start VM
sudo virsh start ubuntu-24-04-server

# Connect to console
sudo virsh console ubuntu-24-04-server

# Get IP address
sudo virsh domifaddr ubuntu-24-04-server

# SSH to VM (replace IP with actual IP)
ssh vagrant@192.168.122.xxx

# Stop VM
sudo virsh shutdown ubuntu-24-04-server

# List all VMs
sudo virsh list --all
```

### VM XML Definition Example

Create a VM definition file `ubuntu-vm.xml`:
```xml
<domain type='kvm'>
  <name>ubuntu-24-04-server</name>
  <memory unit='KiB'>2097152</memory>
  <vcpu placement='static'>2</vcpu>
  <os>
    <type arch='x86_64' machine='pc-i440fx-2.11'>hvm</type>
    <boot dev='hd'/>
  </os>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/ubuntu-24.04-libvirt.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='bridge'>
      <source bridge='virbr0'/>
      <model type='virtio'/>
    </interface>
    <graphics type='spice' autoport='yes'/>
  </devices>
</domain>
```

Then create and start the VM:
```bash
sudo virsh define ubuntu-vm.xml
sudo virsh start ubuntu-24-04-server
```

## Testing the Images

### libvirt Test:
```bash
# Create VM and connect
sudo virt-install --name test-ubuntu --ram 1024 --vcpus 1 \
  --disk path=/var/lib/libvirt/images/ubuntu-24.04-libvirt.qcow2,format=qcow2 \
  --import --network bridge=virbr0 --graphics none --console pty,target_type=serial

# Login as vagrant/vagrant and test
curl --version
wget --version
vim --version
git --version
ping -c 3 google.com
```

## Quick Start Workflows

### For Development and Production (libvirt):
```bash
# Build and deploy with Ansible
make packer-build-libvirt
make ansible-create target_vm=ubuntu-dev
```

### Complete Workflow:
```bash
# One-command setup and build
make setup && make build

# Test with Ansible  
make ansible-create target_vm=ubuntu-dev
```

## License

This configuration is provided as-is for educational purposes. Ubuntu and all mentioned tools are subject to their respective licenses.
