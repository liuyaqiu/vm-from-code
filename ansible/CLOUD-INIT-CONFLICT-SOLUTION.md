# Solution: 50-cloud-init.yaml Conflict

## 🎯 **The Problem You Identified**

You correctly identified that VMs still have `50-cloud-init.yaml` with `enp1s0` configuration. This is the **default network configuration from Ubuntu's cloud image** that gets created automatically.

## 📋 **What Creates 50-cloud-init.yaml**

Ubuntu cloud images contain a built-in cloud-init datasource that automatically creates:
```yaml
# /etc/netplan/50-cloud-init.yaml
# This file is generated from information provided by the datasource.
# This file is managed by cloud-init. Manual changes will be overwritten.
network:
    ethernets:
        enp1s0:
            dhcp4: true
    version: 2
```

This happens **even with clean base images** because cloud-init detects the datasource and generates network configuration.

## 🔧 **The Solution Implemented**

### **1. Disable Cloud-Init Network Handling**
```yaml
# In user-data.j2
network:
  config: disabled
```
This tells cloud-init: "Don't create any automatic network configuration"

### **2. Create Our Own Netplan Configuration**
```yaml
write_files:
  - path: /etc/netplan/99-static-ip.yaml
    content: |
      # Static network configuration - overrides any cloud-init defaults
      network:
        version: 2
        renderer: networkd
        ethernets:
          ens3:        # Most common in libvirt
          enp1s0:      # Your observed interface  
          eth0:        # Fallback
            # Static IP configuration for each
```

### **3. Explicitly Remove Cloud-Init Files**
```bash
runcmd:
  - rm -f /etc/netplan/50-cloud-init.yaml
  - rm -f /etc/netplan/*cloud-init*
  - netplan generate
  - netplan apply
```

## 🎭 **Why This Approach Works**

1. **Disables automatic network creation**: `network: config: disabled`
2. **Creates explicit configuration**: `99-static-ip.yaml` (higher priority than 50-*)
3. **Removes conflicts**: Explicitly deletes cloud-init network files
4. **Covers all interface names**: ens3, enp1s0, eth0 (whatever the VM has)

## 🔍 **How to Verify It Works**

After VM deployment:
```bash
# Connect to VM
ssh vagrant@192.168.122.30

# Check netplan files
sudo ls -la /etc/netplan/
# Should see: 99-static-ip.yaml (NOT 50-cloud-init.yaml)

# Check network configuration
sudo cat /etc/netplan/99-static-ip.yaml

# Check active network
ip addr show
```

## 🏗️ **File Priority in Netplan**

- `50-cloud-init.yaml` - Default cloud-init (removed by us)
- `99-static-ip.yaml` - Our static config (higher priority)

Files with higher numbers (99) take precedence over lower numbers (50).

## ✅ **Expected Results**

After this fix:
- ✅ No more `50-cloud-init.yaml` file
- ✅ Only `99-static-ip.yaml` with static configuration
- ✅ VM gets the correct static IP
- ✅ No interface name conflicts (covers ens3, enp1s0, eth0)

## 🎯 **Root Cause Summary**

The issue wasn't with our Packer build or cloud-init reset. The problem was that Ubuntu cloud images **always** try to create network configuration when they detect a cloud-init datasource (our ISO), regardless of whether the base image had clean state.

The solution is to **explicitly disable cloud-init networking** and **provide our own netplan configuration** that takes precedence.

This is the definitive solution to the cloud-init network conflicts!
