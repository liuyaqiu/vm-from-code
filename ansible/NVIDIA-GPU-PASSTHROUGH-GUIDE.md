# NVIDIA GPU Passthrough Setup Guide

## Overview

This guide documents the complete process for setting up NVIDIA GPU passthrough on Ubuntu systems using KVM/QEMU virtualization. GPU passthrough allows you to dedicate a physical GPU entirely to a virtual machine, providing near-native performance for graphics-intensive applications.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Support](#architecture-support)
- [Automated Setup Process](#automated-setup-process)
- [Manual Configuration Steps](#manual-configuration-steps)
- [Validation Process](#validation-process)
- [Troubleshooting](#troubleshooting)
- [Safety Considerations](#safety-considerations)

## Prerequisites

### Hardware Requirements

- **CPU**: Intel with VT-d support OR AMD with IOMMU/SVM support
- **Motherboard**: Must support IOMMU/VT-d in BIOS/UEFI
- **GPU**: NVIDIA discrete GPU (separate from primary display adapter)
- **Memory**: Sufficient RAM for host + VM requirements
- **Storage**: Adequate space for VM disk images

### Software Requirements

- **Host OS**: Ubuntu 20.04+ (tested with Ubuntu 24.04)
- **Kernel**: Linux 6.0+ (recommended 6.14+)
- **Virtualization**: KVM/QEMU with libvirt
- **Ansible**: For automated configuration

### Network Requirements

- Internet connection for package installation
- Ansible control machine access to target host

## Architecture Support

### Intel Platform
- **CPU Features**: VT-x, VT-d
- **BIOS Settings**: Enable Intel VT-d, disable Secure Boot
- **Kernel Parameters**: `intel_iommu=on iommu=pt`

### AMD Platform  
- **CPU Features**: SVM Mode, AMD-Vi/IOMMU
- **BIOS Settings**: Enable AMD IOMMU/SVM Mode, disable Secure Boot
- **Kernel Parameters**: `amd_iommu=on iommu=pt`

## Automated Setup Process

The `setup-gpu-passthrough.yml` ansible playbook automates safe operations while prompting for critical manual steps.

### Run the Playbook

```bash
cd /path/to/ansible
ansible-playbook -i inventory.yml setup-gpu-passthrough.yml
```

### What the Playbook Does Automatically

✅ **Platform Detection**
- Detects Intel vs AMD CPU architecture
- Provides platform-specific BIOS guidance
- Checks current IOMMU status

✅ **GPU Discovery** 
- Scans for all GPU devices
- Identifies NVIDIA GPUs specifically
- Extracts PCI vendor:device IDs

✅ **Driver Analysis**
- Checks for NVIDIA proprietary drivers
- Monitors nouveau driver status
- Identifies potential conflicts

✅ **VFIO Configuration**
- Creates `/etc/modules-load.d/vfio.conf`
- Loads required VFIO modules
- Configures module dependencies

✅ **Nouveau Blacklisting**
- Creates `/etc/modprobe.d/blacklist-nouveau.conf`
- Prevents nouveau from binding to target GPU

✅ **Package Installation**
- Installs qemu-kvm, libvirt-daemon-system
- Installs virt-manager, bridge-utils
- Installs cpu-checker utilities

### What Requires Manual Action

🔶 **BIOS/UEFI Configuration**
- Enable IOMMU/VT-d features
- Disable Secure Boot (recommended)
- Enable CPU virtualization features

🔶 **NVIDIA Driver Removal** (if installed)
- Remove proprietary NVIDIA drivers
- Clean up related packages
- Reboot after removal

🔶 **GRUB Configuration**
- Edit `/etc/default/grub`
- Add kernel parameters
- Update GRUB and initramfs
- System reboot

🔶 **Validation Testing**
- Verify IOMMU activation
- Confirm GPU binding to vfio-pci
- Test IOMMU group isolation

## Manual Configuration Steps

### Step 1: BIOS/UEFI Configuration

**For Intel Systems:**
1. Enter BIOS/UEFI setup during boot
2. Navigate to CPU/Chipset settings
3. Enable **Intel VT-d** (Virtualization Technology for Directed I/O)
4. Enable **Intel VT-x** (Virtualization Technology)
5. **Disable Secure Boot** (in Security settings)
6. Save and exit

**For AMD Systems:**
1. Enter BIOS/UEFI setup during boot
2. Navigate to CPU/Chipset settings  
3. Enable **AMD IOMMU** or **SVM Mode**
4. Enable **AMD-V** (Virtualization)
5. **Disable Secure Boot** (in Security settings)
6. Save and exit

### Step 2: Remove NVIDIA Proprietary Drivers

If the playbook detects existing NVIDIA drivers:

```bash
# Remove NVIDIA packages
sudo apt remove --purge nvidia-* libnvidia-*
sudo apt autoremove

# Reboot to ensure clean state
sudo reboot
```

### Step 3: GRUB Configuration

The playbook will provide the exact kernel parameters for your system. Example:

**For AMD Systems:**
```bash
# Edit GRUB configuration
sudo vim /etc/default/grub

# Find this line:
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"

# Change to (example - use parameters from playbook):
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on iommu=pt"
```

**For Intel Systems:**
```bash
# Example Intel configuration:
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on iommu=pt"
```

**Apply Changes:**
```bash
# Update GRUB
sudo update-grub

# Update initramfs
sudo update-initramfs -u

# Reboot system
sudo reboot
```

### Step 4: Audio Device Handling

If your GPU has integrated audio (HDMI/DisplayPort):

```bash
# Find audio device ID
lspci -nn | grep -i nvidia

# Example output:
# 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation Device [10de:2c02]
# 01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:22e9]

# Add both IDs to GRUB:
vfio-pci.ids=10de:2c02,10de:22e9
```

## Validation Process

After reboot, verify the configuration:

### 1. Kernel Parameters
```bash
cat /proc/cmdline
# Should show your added parameters
```

### 2. IOMMU Status
```bash
# For AMD:
dmesg | grep -i "AMD-Vi: AMD IOMMU Enabled"

# For Intel:  
dmesg | grep -i "DMAR: IOMMU enabled"
```

### 3. VFIO Modules
```bash
lsmod | grep vfio
# Should show: vfio, vfio_pci, vfio_iommu_type1, etc.
```

### 4. GPU Driver Binding
```bash
lspci -k | grep -EA3 'VGA|3D|Display'
# Look for "Kernel driver in use: vfio-pci" on your NVIDIA GPU
```

### 5. IOMMU Groups
```bash
# Find GPU's IOMMU group
readlink /sys/bus/pci/devices/0000:01:00.0/iommu_group

# List devices in the group (replace X with group number)
ls -la /sys/kernel/iommu_groups/X/devices/
```

### Expected Success Indicators

✅ IOMMU enabled in kernel messages  
✅ VFIO modules loaded (vfio, vfio_pci, vfio_iommu_type1)  
✅ NVIDIA GPU shows "Kernel driver in use: vfio-pci"  
✅ GPU and its audio device in same IOMMU group  
✅ Nouveau driver not loaded (`lsmod | grep nouveau` returns nothing)  

## Troubleshooting

### Common Issues

**IOMMU Not Enabled**
- Verify BIOS settings are correct
- Check kernel parameters in `/proc/cmdline`
- Ensure compatible CPU/motherboard

**GPU Still Using Nouveau**
- Verify blacklist file: `/etc/modprobe.d/blacklist-nouveau.conf`
- Check GRUB parameters include correct device ID
- Ensure initramfs was updated after changes

**IOMMU Group Conflicts**
- GPU shares group with other critical devices
- May need ACS override patches (advanced)
- Consider different PCIe slot if available

**Boot Issues After GRUB Changes**
- Boot from recovery media
- Edit GRUB parameters temporarily
- Remove problematic kernel parameters

### Debugging Commands

```bash
# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort -V

# Verify PCI device details
lspci -vnn | grep -A 15 nvidia

# Check kernel messages
dmesg | grep -E "IOMMU|VFIO|nvidia"

# Verify module loading
modinfo vfio-pci
```

## Safety Considerations

### Before Starting

⚠️ **Backup Critical Data**
- Full system backup recommended
- Document current working configuration
- Prepare recovery media

⚠️ **System Requirements**
- Ensure you have alternative access (SSH, secondary GPU)
- Have recovery boot media available
- Understand how to reset BIOS/UEFI settings

### During Configuration

⚠️ **GRUB Modifications**
- Double-check kernel parameters before applying
- Understand each parameter's purpose
- Keep a copy of original GRUB configuration

⚠️ **Driver Changes**
- Only remove drivers when specifically required
- Reboot between major changes
- Verify system stability after each step

### Recovery Options

**Boot Issues:**
1. Use GRUB recovery mode
2. Edit kernel parameters temporarily
3. Reset to last known good configuration

**Display Issues:**
1. SSH access for remote management
2. Integrated GPU for basic display
3. Recovery media for system repair

## Virtual Machine Configuration

After successful GPU passthrough setup:

### libvirt VM Configuration

Add to VM's XML configuration:
```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
  </source>
  <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
</hostdev>
```

### virt-manager Configuration

1. Open VM settings
2. Add Hardware → PCI Host Device
3. Select your NVIDIA GPU
4. Also add audio device if present
5. Configure VM with sufficient resources

### Performance Optimization

- **CPU Pinning**: Pin VM cores to physical cores
- **Huge Pages**: Enable for better memory performance  
- **MSI Interrupts**: Enable for reduced latency
- **CPU Governor**: Set to performance mode
- **NUMA Topology**: Configure for optimal placement

## Additional Resources

### Documentation
- [VFIO Documentation](https://www.kernel.org/doc/Documentation/vfio.txt)
- [KVM Documentation](https://www.linux-kvm.org/page/Documents)
- [libvirt Domain XML](https://libvirt.org/formatdomain.html)

### Community Support
- [VFIO Reddit Community](https://reddit.com/r/VFIO)
- [Level1Techs Forum](https://forum.level1techs.com)
- [Arch Linux VFIO Wiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)

### Hardware Compatibility
- [IOMMU Hardware Database](https://github.com/clayfreeman/gpu-passthrough)
- [VFIO Hardware Compatibility](https://vfio.blogspot.com/)

---

## Conclusion

This guide provides a comprehensive approach to NVIDIA GPU passthrough setup with emphasis on safety and automation. The ansible playbook handles routine configuration while ensuring critical decisions remain under user control.

For questions or issues, consult the troubleshooting section or community resources listed above.

**Last Updated**: December 2024  
**Tested On**: Ubuntu 24.04, AMD Ryzen 9 9950X, NVIDIA RTX Series  
**Ansible Version**: 2.14+
