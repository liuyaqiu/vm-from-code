# PCI Bus Ordering Fix for VMs with Filesystem and Network Devices

## Problem

When creating VMs with both shared folders (virtiofs filesystem devices) and network interfaces, the libvirt/Terraform provider may assign PCI bus addresses in the wrong order:

- **Incorrect**: Filesystem on bus 0x01, Network on bus 0x02
- **Correct**: Network on bus 0x01, Filesystem on bus 0x02+

The incorrect ordering causes the network interface to not work properly inside the VM.

## Root Cause

The Terraform libvirt provider assigns PCI bus addresses automatically when devices are added to the domain. If the filesystem device is defined before the network interface in the configuration, it may get a lower bus number (0x01), pushing the network interface to a higher bus (0x02+).

In Linux VMs, network interfaces are typically named based on their PCI bus location (e.g., `ens1` for bus 0x01, `ens2` for bus 0x02). If the network gets assigned to bus 0x02 due to the filesystem being on 0x01, the cloud-init network configuration (which expects `ens1`) will fail.

## Solution

### 1. Preventive Fix (For New VMs)

The Terraform template `vm-terraform.tf.j2` has been updated to explicitly set PCI bus addresses:

- **Network interface**: Always on bus 0x01 (lines 119-128)
- **Filesystem devices**: Starting from bus 0x02 (lines 173-181)

New VMs created with the updated template will have the correct PCI bus ordering.

### 2. Corrective Fix (For Existing VMs)

For VMs that already have the incorrect PCI bus ordering, use the manual fix workflow:

```bash
cd ansible
make fix-pci-bus VM=terraform-test IDX=0
```

This will:
1. Dump the current VM XML configuration
2. Destroy the VM (stop and undefine)
3. Delete the VM's disk image
4. Create a fixed XML with swapped PCI bus addresses
5. Recreate the disk from the source image
6. Define and start the VM with the fixed XML

### 3. Manual Fix Using Ansible Playbook

You can also run the fix playbook directly:

```bash
cd ansible
ansible-playbook -i inventory.yml fix-vm-pci-bus.yml \
  -e target_vm=terraform-test \
  -e replica_index=0
```

## What the Fix Does

The fix workflow (`fix-vm-pci-bus.yml`) is robust and performs these steps:

1. **Check VM exists**: Verifies the VM is defined in libvirt
2. **Dump XML**: Saves current configuration to `terraform/<vm>/<vm>-<idx>.xml`
3. **Check if fix needed**: Analyzes the XML to determine if PCI bus reordering is necessary
   - If network interface is already on bus 0x01: **Skip fix** (idempotent)
   - If VM has no filesystem devices: **Skip fix** (nothing to fix)
   - Otherwise: Proceed with fix
4. **Destroy VM**: Stops and undefines the VM (keeps cloud-init ISO)
5. **Delete disk**: Removes only the VM's qcow2 disk image
6. **Fix XML**: Uses Python to intelligently reorder PCI bus addresses:
   - Network interface → bus 0x01
   - All other devices with bus >= 0x01 → incremented by 1
7. **Save fixed XML**: Saves modified configuration to `terraform/<vm>/<vm>-<idx>_fixed.xml`
8. **Recreate disk**: Copies and resizes the source image
9. **Define VM**: Creates VM with fixed XML
10. **Start VM**: Boots the VM

### Intelligent Bus Reordering

The fix script doesn't just swap filesystem and network buses. Instead, it:
- Ensures network interface is on bus 0x01
- Increments **all** other devices (filesystem, controllers, etc.) that are on bus >= 0x01
- This prevents conflicts and maintains proper device ordering

## Files

- **[fix-vm-pci-bus.yml](fix-vm-pci-bus.yml)**: Ansible playbook for the manual fix
- **[Makefile](Makefile)**: Convenience target `fix-pci-bus`
- **[templates/vm-terraform.tf.j2](templates/vm-terraform.tf.j2)**: Terraform template with PCI address configuration

## Verification

After running the fix, verify the PCI bus ordering:

```bash
# Check VM XML
virsh -c qemu:///session dumpxml terraform-test-0 | grep -A 10 'interface\|filesystem'

# SSH into VM and check network interface
make ssh VM=terraform-test@0
ip addr show  # Should show ens1 with the correct IP
```

Expected XML output:
```xml
<interface type='bridge'>
  <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
  ...
</interface>

<filesystem type='mount' accessmode='passthrough'>
  <address type='pci' domain='0x0000' bus='0x02' slot='0x00' function='0x0'/>
  ...
</filesystem>
```

## Prevention

To prevent this issue in new VMs:

1. Always use the latest Terraform template (`vm-terraform.tf.j2`)
2. The template now explicitly sets PCI addresses for both network and filesystem devices
3. Network interface is hardcoded to bus 0x01
4. Filesystem devices start from bus 0x02 (using Jinja2 loop index)

## Technical Details

### PCI Bus Assignment Priority

In QEMU/KVM VMs using the q35 machine type:
- Bus 0x00: Reserved for root complex and controllers
- Bus 0x01+: Available for PCIe devices

The order matters because:
- Cloud-init network config expects interface naming based on bus order
- Ubuntu/Linux predictable interface naming uses PCI bus topology
- Interface `ens1` corresponds to the first PCIe device (typically bus 0x01)

### Why Filesystem Gets Priority

In Terraform's libvirt provider, devices are added in the order they appear in the configuration. The Terraform template defines devices in this order:
1. Disks
2. Interfaces
3. Graphics
4. Serials/consoles
5. RNG
6. Filesystems (if configured)
7. Hostdevs (GPU passthrough, if configured)

However, the actual PCI bus assignment may vary based on internal provider logic, which is why explicit addressing is necessary.

## References

- [Libvirt Domain XML Format](https://libvirt.org/formatdomain.html#device-addresses)
- [QEMU Q35 Machine Type](https://wiki.qemu.org/Features/Q35)
- [Linux Predictable Network Interface Names](https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/)
