# Migration to Ubuntu Cloud Images

This document explains the migration from Ubuntu live server ISO to Ubuntu cloud images for faster VM image building.

## What Changed

### Before (Live Server ISO)
- Used Ubuntu 24.04.3 live server ISO (1.8GB download)
- Required interactive installation process with autoinstall
- Needed complex boot commands and HTTP server for autoinstall configuration
- Build time: 15-30 minutes including OS installation
- Supported both VirtualBox and QEMU/libvirt

### After (Cloud Images)
- Uses Ubuntu 24.04 cloud image (≈350MB download)
- Pre-installed, ready-to-boot image
- No installation process needed
- Uses cloud-init for initial configuration
- Build time: 3-5 minutes (much faster!)
- Currently optimized for QEMU/libvirt (VirtualBox support can be added later)

## Key Benefits

1. **Speed**: 5-10x faster builds since no OS installation is required
2. **Efficiency**: Smaller download size (350MB vs 1.8GB)
3. **Reliability**: Cloud images are pre-tested and optimized
4. **Simplicity**: No complex boot commands or autoinstall configuration
5. **Cloud-native**: Uses cloud-init, which is standard for cloud deployments

## New Configuration Structure

### Variables (`variables.pkrvars.hcl`)
```hcl
# Now using cloud image instead of ISO
source_image_url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
source_image_checksum = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
```

### Cloud-Init Configuration (`cloud-init/`)
- `cloud-init/user-data`: Configures users, packages, and SSH
- `cloud-init/meta-data`: Basic instance metadata

The cloud-init configuration automatically:
- Creates the `vagrant` user with proper sudo access
- Installs the Vagrant insecure SSH key
- Installs required packages
- Configures SSH access

### QEMU Source
Now uses `disk_image = true` and cloud-init for configuration:
```hcl
source "qemu" "ubuntu" {
  disk_image = true
  iso_url = var.source_image_url
  iso_checksum = var.source_image_checksum
  
  # Cloud-init configuration
  cd_files = [
    "cloud-init/user-data",
    "cloud-init/meta-data"
  ]
  cd_label = "cidata"
  
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  # ... other settings
}
```

## How to Build

### QEMU/libvirt Build (Recommended)
```bash
# Build the libvirt-compatible image
packer build -only=libvirt ubuntu-24.04.pkr.hcl

# Or with custom variables
packer build -only=libvirt -var-file=variables.pkrvars.hcl ubuntu-24.04.pkr.hcl
```

This creates:
- `builds/ubuntu-24.04-libvirt.qcow2` (final image for libvirt)

### Testing the Build
```bash
# Validate configuration
packer validate ubuntu-24.04.pkr.hcl

# Build with verbose output
packer build -debug -only=libvirt ubuntu-24.04.pkr.hcl
```

## Migration Notes

### What Was Removed
- VirtualBox build (temporarily, can be re-added with proper cloud image conversion)
- `http/` directory (no longer needed for autoinstall)
- Complex boot commands
- Interactive installation process

### What Was Updated
- Variables now point to cloud images instead of ISO
- SSH configuration uses `vagrant` user (created by cloud-init)
- Build process waits for cloud-init completion instead of installation
- Provisioning scripts updated to work with pre-existing vagrant user

### Backwards Compatibility
The old ISO-based configuration is preserved in git history. If you need to revert:
```bash
git checkout <previous-commit> ubuntu-24.04.pkr.hcl variables.pkrvars.hcl
```

## Cloud Image Updates

Ubuntu cloud images are updated regularly. The configuration uses:
- `noble-server-cloudimg-amd64.img` (latest Ubuntu 24.04 cloud image)
- `file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS` for checksum verification

The checksum file ensures you always get the latest verified cloud image.

## Troubleshooting

### Common Issues

1. **SSH Connection Fails**
   - Ensure cloud-init has completed: check the pause_before setting
   - Verify vagrant user was created by cloud-init

2. **Build Fails with "disk_image" Error**
   - Make sure you're using a recent version of Packer with QEMU plugin
   - Verify the cloud image URL is accessible

3. **Cloud-init Doesn't Run**
   - Check the `cd_files` configuration points to correct paths
   - Verify `cloud-init/user-data` and `cloud-init/meta-data` exist

### Debug Commands
```bash
# Check cloud-init status during build
cloud-init status --wait

# View cloud-init logs
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log

# Check if vagrant user was created
id vagrant
sudo cat /etc/passwd | grep vagrant
```

## Future Enhancements

1. **VirtualBox Support**: Add cloud image support for VirtualBox
2. **Multi-arch**: Support ARM64 cloud images
3. **Custom Cloud Images**: Use organization-specific base images
4. **Automated Updates**: Script to update to latest cloud image checksums

## Performance Comparison

| Metric | Live Server ISO | Cloud Image | Improvement |
|--------|----------------|-------------|-------------|
| Download Size | 1.8GB | ~350MB | 5x smaller |
| Build Time | 15-30 min | 3-5 min | 5-10x faster |
| CPU Usage | High (installation) | Low (boot only) | Significant |
| Reliability | Variable | High | More stable |

The cloud image approach is significantly more efficient and should be the preferred method for CI/CD pipelines and development workflows.
