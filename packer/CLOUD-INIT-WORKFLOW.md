# Cloud-Init Best Practices: Packer + Ansible

## 🎯 **The Problem We Solved**

Before: Packer builds contained cloud-init configurations that conflicted with deployment-time configurations, making debugging difficult.

After: Clean separation between build-time and deployment-time cloud-init usage.

## 🏗️ **Improved Workflow**

### **Phase 1: Packer Build (Base Image Creation)**

```bash
# Build clean base image
packer build ubuntu-24.04.pkr.hcl
```

**What happens during build:**
1. Uses minimal cloud-init to create vagrant user and install base packages
2. **CRITICAL**: Resets cloud-init state completely after provisioning
3. Removes all cloud-init logs, instances, and network configurations
4. Produces a clean base image ready for deployment

**Cloud-init reset commands in Packer:**
```bash
sudo cloud-init clean --logs
sudo rm -rf /var/lib/cloud/instances/*
sudo rm -rf /var/lib/cloud/instance
sudo rm -rf /var/log/cloud-init*
sudo rm -rf /etc/netplan/50-cloud-init.yaml
sudo rm -rf /etc/netplan/*cloud-init*
```

### **Phase 2: Ansible Deployment (Environment-Specific)**

```bash
# Deploy with environment-specific configuration
cd ansible
make cloud-vm  # or make create VM=ubuntu-dev
```

**What happens during deployment:**
1. Ansible creates fresh cloud-init ISO with deployment-specific config
2. VM boots with clean cloud-init state
3. Cloud-init applies environment-specific network/app configuration
4. No conflicts because base image has clean state

## 📁 **File Structure**

```
learn-packer/
├── ubuntu-24.04.pkr.hcl              # Main Packer config (with cloud-init reset)
├── cloud-init/                       # Build-time cloud-init (minimal)
│   ├── user-data                      # Basic user creation only
│   └── meta-data                      # Build instance metadata
├── ansible/
│   ├── templates/
│   │   ├── user-data.j2              # Deployment-time cloud-init
│   │   └── vm-config.xml.j2          # VM configuration
│   ├── inventory.yml                  # VM definitions with static IPs
│   └── create-vm.yml                  # VM creation playbook
└── scripts/
    ├── provision.sh                   # Base package installation
    ├── vagrant.sh                     # Vagrant user setup
    └── cleanup.sh                     # Final cleanup
```

## 🔄 **Environment-Specific Deployments**

### **Development Environment**
```yaml
ubuntu-dev:
  vm_static_ip: "192.168.122.10"
  vm_memory: 2048
  vm_vcpus: 2
```

### **GPU Environment**
```yaml
ubuntu-gpu:
  vm_static_ip: "192.168.122.11"
  vm_memory: 4096
  vm_vcpus: 4
```

## 🐛 **Debugging**

### **Build-time Issues**
```bash
# Check Packer logs
export PACKER_LOG=1
packer build ubuntu-24.04.pkr.hcl

# Verify cloud-init reset worked
# (Check manually that build completed cloud-init reset step)
```

### **Deployment-time Issues**
```bash
# Use debug script
./debug-cloud-init.sh ubuntu-dev

# Check VM cloud-init status
virt-viewer ubuntu-dev
# Then in VM:
sudo cloud-init status --long
sudo cat /var/log/cloud-init.log
sudo cat /etc/netplan/*.yaml
```

## ✅ **Benefits of This Approach**

1. **Clean Separation**: Build vs. deployment concerns clearly separated
2. **Environment Flexibility**: Same base image, different deployment configs
3. **Easier Debugging**: Know exactly which phase caused issues
4. **Immutable Infrastructure**: Base image never changes
5. **Conflict Prevention**: No leftover cloud-init state from build

## 🚀 **Usage Examples**

```bash
# Build once
packer build ubuntu-24.04.pkr.hcl

# Deploy many times with different configs
cd ansible
make create VM=ubuntu-dev      # Development environment
make create VM=ubuntu-staging  # Staging environment  
make create VM=ubuntu-prod     # Production environment

# Each deployment gets its own cloud-init configuration
# No conflicts, predictable behavior
```

## 📋 **Checklist for New Environments**

1. Add VM definition to `ansible/inventory.yml`
2. Specify environment-specific settings (IP, memory, etc.)
3. Deploy: `make create VM=your-vm-name`
4. Cloud-init will apply your specific configuration
5. Debug if needed: `./debug-cloud-init.sh your-vm-name`

This approach eliminates the cloud-init conflicts and makes the entire workflow predictable and debuggable.
