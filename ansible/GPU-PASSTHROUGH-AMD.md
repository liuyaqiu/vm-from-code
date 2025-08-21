# GPU Passthrough Setup for AMD Systems

This guide provides step-by-step instructions for setting up GPU passthrough on AMD-based systems with your detected hardware.

## 🖥️ **Detected Hardware**

Your system has the following GPUs available for passthrough:
- **NVIDIA RTX A6000** - PCI ID: `01:00.0` - Device ID: `10de:2230`
- **AMD GPU** - PCI ID: `11:00.0` - Device ID: `1002:164e`

## 🔧 **Prerequisites**

### 1. BIOS/UEFI Configuration

Access your BIOS/UEFI settings and enable:
- **AMD-Vi (IOMMU)** - Usually found in "Advanced" or "CPU Configuration"
- **SVM Mode** (if available)
- **Above 4G Decoding** (if available)
- **Resizable BAR** (if available and supported by GPU)

### 2. Verify AMD-Vi Support

After enabling in BIOS, check if AMD-Vi is working:

```bash
# Check if AMD-Vi is enabled
dmesg | grep -i "AMD-Vi"

# Should show something like:
# AMD-Vi: Found IOMMU at 0000:00:00.2 cap 0x40
# AMD-Vi: Lazy IO/TLB flushing enabled
```

## ⚙️ **Setup Process**

### Step 1: Update Kernel Parameters

Edit GRUB configuration:
```bash
sudo nano /etc/default/grub
```

For **AMD systems**, modify the `GRUB_CMDLINE_LINUX` line:

#### For NVIDIA RTX A6000 passthrough:
```bash
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt vfio-pci.ids=10de:2230"
```

#### For AMD GPU passthrough:
```bash
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt vfio-pci.ids=1002:164e"
```

#### For both GPUs (dual passthrough):
```bash
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt vfio-pci.ids=10de:2230,1002:164e"
```

**Parameter Explanation:**
- `amd_iommu=on` - Enables AMD IOMMU (Intel uses `intel_iommu=on`)
- `iommu=pt` - Sets IOMMU to passthrough mode for better performance
- `vfio-pci.ids=` - Binds specific GPU devices to VFIO driver

### Step 2: Update GRUB and Reboot

```bash
sudo update-grub
sudo reboot
```

### Step 3: Verify VFIO Binding

After reboot, verify the GPU is bound to VFIO:

```bash
# Check if GPU is bound to vfio-pci
lspci -k | grep -A 3 -i vga

# Should show "Kernel driver in use: vfio-pci" for passthrough GPU
```

### Step 4: Run Ansible GPU Setup

```bash
cd ansible
make gpu-setup
```

This will:
- Load required VFIO modules
- Configure module loading at boot
- Verify IOMMU groups

## 🚀 **Create GPU-Enabled VMs**

### Option 1: NVIDIA RTX A6000 VM

Update `ansible/inventory.yml`:
```yaml
ubuntu-gpu-nvidia:
  vm_name: "ubuntu-gpu-nvidia"
  vm_memory: 8192
  vm_vcpus: 4
  vm_disk_size: "80G"
  vm_network: "default"
  gpu_passthrough: true
  gpu_device_id: "0000:01:00.0"  # NVIDIA RTX A6000
```

Create the VM:
```bash
make create VM=ubuntu-gpu-nvidia
```

### Option 2: AMD GPU VM

Update `ansible/inventory.yml`:
```yaml
ubuntu-gpu-amd:
  vm_name: "ubuntu-gpu-amd"
  vm_memory: 8192
  vm_vcpus: 4
  vm_disk_size: "80G"
  vm_network: "default"
  gpu_passthrough: true
  gpu_device_id: "0000:11:00.0"  # AMD GPU
```

Create the VM:
```bash
make create VM=ubuntu-gpu-amd
```

## 🔍 **Verification and Troubleshooting**

### Check IOMMU Groups

```bash
# List all IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort -V

# Check specific GPU IOMMU group
lspci -nn | grep VGA
```

### Verify GPU in VM

Once VM is running, connect via VNC and check:
```bash
# In the VM, check if GPU is detected
lspci | grep VGA
lshw -c display
```

### Common Issues and Solutions

#### 1. "IOMMU not found" Error
- **Solution**: Ensure AMD-Vi is enabled in BIOS
- **Check**: `dmesg | grep -i iommu`

#### 2. GPU still shows host driver
- **Solution**: Add GPU PCI ID to blacklist
```bash
echo "blacklist nouveau" | sudo tee -a /etc/modprobe.d/blacklist.conf
echo "blacklist radeon" | sudo tee -a /etc/modprobe.d/blacklist.conf
echo "blacklist amdgpu" | sudo tee -a /etc/modprobe.d/blacklist.conf
sudo update-initramfs -u
```

#### 3. VM fails to start
- **Check IOMMU groups**: Ensure GPU is in isolated group
- **Check logs**: `journalctl -u libvirtd`
- **Try different GPU**: Some GPUs work better than others

## 📋 **AMD-Specific GRUB Parameters**

Here are additional AMD-specific parameters you might need:

```bash
# Basic setup (most common)
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt vfio-pci.ids=10de:2230"

# With additional AMD optimizations
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt kvm_amd.npt=1 kvm_amd.avic=1 vfio-pci.ids=10de:2230"

# For systems with multiple GPUs (isolation)
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt video=efifb:off vfio-pci.ids=10de:2230"

# With CPU isolation for better performance
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt isolcpus=2-7 vfio-pci.ids=10de:2230"
```

**Parameter Details:**
- `kvm_amd.npt=1` - Enable Nested Page Tables
- `kvm_amd.avic=1` - Enable AMD Advanced Virtual Interrupt Controller
- `video=efifb:off` - Disable EFI framebuffer (prevents conflicts)
- `isolcpus=2-7` - Isolate CPU cores for VM use

## 🎮 **Gaming and GPU-Intensive Workloads**

For optimal gaming or GPU compute performance:

### 1. CPU Pinning Configuration

Add to your VM configuration in `inventory.yml`:
```yaml
ubuntu-gaming:
  vm_name: "ubuntu-gaming"
  vm_memory: 16384
  vm_vcpus: 8
  vm_disk_size: "200G"
  vm_network: "default"
  gpu_passthrough: true
  gpu_device_id: "0000:01:00.0"
  cpu_mode: "host-passthrough"
  cpu_topology: "4,2,1"  # sockets,cores,threads
```

### 2. Hugepages for Performance

```bash
# Enable hugepages (add to GRUB)
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt hugepagesz=1G hugepages=16 vfio-pci.ids=10de:2230"

# Verify hugepages
cat /proc/meminfo | grep -i huge
```

## 🔧 **Quick Commands Reference**

```bash
# Check AMD-Vi status
dmesg | grep -i "amd-vi"

# List IOMMU groups
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do echo "IOMMU Group ${g##*/}:"; for d in $g/devices/*; do echo -e "\t$(lspci -nns ${d##*/})"; done; done

# Check VFIO devices
ls -la /dev/vfio/

# Monitor VM performance
sudo virsh domstats ubuntu-gpu-nvidia

# Reset GPU (if needed)
echo 1 | sudo tee /sys/bus/pci/devices/0000:01:00.0/reset
```

## 🚨 **Important Notes for AMD Systems**

1. **CPU Compatibility**: Ensure your AMD CPU supports AMD-Vi (most modern Ryzen and EPYC do)
2. **Motherboard**: Verify motherboard supports IOMMU
3. **GPU Isolation**: Some AMD GPUs share IOMMU groups with other devices
4. **Driver Conflicts**: AMD systems may have different driver binding behavior
5. **Performance**: AMD systems often benefit from CPU isolation and hugepages

## 🔄 **Switching Between Host and VM GPU**

To switch GPU back to host:
```bash
# Stop VM
make stop VM=ubuntu-gpu-nvidia

# Unbind from VFIO
echo 0000:01:00.0 | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind

# Bind to host driver (nouveau/nvidia)
echo 0000:01:00.0 | sudo tee /sys/bus/pci/drivers/nvidia/bind

# Or reboot for automatic binding
sudo reboot
```

---

💡 **Need Help?** Check the logs with `journalctl -u libvirtd` and ensure all BIOS settings are correct for AMD systems.
