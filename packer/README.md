# Packer Configuration for Ubuntu 24.04

This directory contains the Packer configuration files for building Ubuntu 24.04 images for libvirt/KVM.

## Files Overview

- `ubuntu-24.04.pkr.hcl` - Main Packer configuration with source definitions and build blocks
- `variables.pkrvars.hcl` - Variables file for customizing VM resources and image URLs
- `cloud-init/` - Cloud-init configuration files for automated OS setup
- `scripts/` - Provisioning scripts for package installation and system configuration
- `CLOUD-IMAGE-MIGRATION.md` - Documentation about cloud image migration process
- `CLOUD-INIT-WORKFLOW.md` - Documentation about cloud-init workflow

## Building Images

**Recommended**: Use the root Makefile for automatic dependency installation:

```bash
# From the project root directory (auto-installs Packer if needed)
make setup              # One-command setup (install + init)
make build              # Build libvirt image
```

Or use specific targets:

```bash
make packer-install     # Install Packer automatically
make packer-init        # Initialize Packer plugins  
make packer-validate    # Validate configuration
make packer-build-libvirt # Build libvirt image
```

**Manual approach** (requires Packer to be pre-installed):

```bash
# From the packer/ directory
packer init ubuntu-24.04.pkr.hcl
packer validate ubuntu-24.04.pkr.hcl
packer build -only='libvirt.*' ubuntu-24.04.pkr.hcl
```

## Configuration Details

### Variables
The `variables.pkrvars.hcl` file contains customizable variables:
- `vm_name` - Virtual machine name
- `disk_size` - Disk size in MB
- `memory` - RAM in MB
- `cpus` - Number of CPU cores
- `source_image_url` - Ubuntu cloud image URL
- `source_image_checksum` - Image checksum for verification

### Cloud-init Configuration
The `cloud-init/` directory contains:
- `user-data` - User configuration, packages, and SSH setup
- `meta-data` - Instance metadata and hostname configuration

### Provisioning Scripts
The `scripts/` directory contains:
- `provision.sh` - Install packages and system updates
- `vagrant.sh` - Configure the vagrant user for access
- `cleanup.sh` - Clean up temporary files and optimize image size

## Output

Built images are placed in the `../builds/` directory:
- `ubuntu-24.04-libvirt.qcow2` - Raw qcow2 image for libvirt/KVM

## Customization

To customize the image:

1. **Modify VM resources**: Edit `variables.pkrvars.hcl`
2. **Add packages**: Edit `scripts/provision.sh`
3. **Change cloud-init setup**: Edit `cloud-init/user-data`
4. **Modify user setup**: Edit `scripts/vagrant.sh`

## Troubleshooting

If builds fail:
1. Try the automated setup: `make setup` (installs all dependencies)
2. Check that virtualization is enabled (KVM support)
3. Ensure the output directory doesn't already exist: `make clean`
4. Verify internet connectivity for downloading dependencies and base image
5. Check cloud-init syntax in the user-data file
6. For dependency issues, manually install: `make install`
