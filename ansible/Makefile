# Ansible libvirt VM Management Makefile

.PHONY: help install setup list create start stop restart destroy gpu-setup build-image cloud-vm ssh ssh-pass

# Default target
help:
	@echo "Available targets:"
	@echo ""
	@echo "  === Setup ==="
	@echo "  install        - Install Ansible and required collections"
	@echo "  setup          - Setup libvirt environment"
	@echo ""
	@echo "  === Image Building ==="
	@echo "  build-image    - Build Ubuntu cloud image with Packer (fast!)"
	@echo ""
	@echo "  === VM Management ==="
	@echo "  list           - List all VMs and their status"
	@echo "  create VM=name - Create and start VM (e.g., make create VM=ubuntu-dev)"
	@echo "  cloud-vm       - Quick create cloud VM for development (uses ubuntu-dev)"
	@echo "  start VM=name  - Start VM"
	@echo "  stop VM=name   - Stop VM gracefully"
	@echo "  restart VM=name- Restart VM"
	@echo "  destroy VM=name- Destroy VM completely"
	@echo "  destroy-all VM=name - Destroy VM and clean up base image (affects all VMs)"
	@echo "  ssh [VM=name]  - SSH into VM using SSH key (default: ubuntu-dev)"
	@echo "  ssh-pass [VM=name] - SSH into VM using password (default: ubuntu-dev)"
	@echo ""
	@echo "  === GPU Features ==="
	@echo "  gpu-setup      - Setup GPU passthrough (see GPU-PASSTHROUGH-AMD.md)"
	@echo ""
	@echo "  === Recommended Usage ==="
	@echo "  1. make install        # First time setup"
	@echo "  2. make setup          # Setup libvirt + static DHCP network"
	@echo "  3. make build-image    # Build clean base image with reset cloud-init"
	@echo "  4. make cloud-vm       # Deploy VM with environment-specific cloud-init"
	@echo "  help           - Show this help message"

# Install Ansible and required collections
install:
	@echo "Installing Ansible and collections..."
	pip3 install ansible
	ansible-galaxy collection install -r requirements.yml

# Setup libvirt environment
setup:
	ansible-playbook -i inventory.yml create-vm.yml --tags setup,network --ask-become-pass

# Build clean base image with Packer (NEW WORKFLOW)
build-image:
	@echo "Building clean Ubuntu base image with Packer..."
	@echo "This image will have reset cloud-init state for deployment flexibility"
	@cd .. && packer build -only=libvirt.qemu.ubuntu ubuntu-24.04.pkr.hcl
	@echo "✅ Clean base image built successfully!"
	@echo "Image location: ../builds/ubuntu-24.04-server.qcow2"
	@echo "Cloud-init state has been reset - ready for deployment-specific configuration"

# Quick cloud VM creation for development (NEW WORKFLOW)
cloud-vm:
	@echo "Deploying development VM with environment-specific cloud-init..."
	@echo "Using clean base image with deployment-time network configuration"
	ansible-playbook -i inventory.yml create-vm.yml -e target_vm=ubuntu-dev --ask-become-pass
	@echo "✅ VM 'ubuntu-dev' deployed with static IP!"
	@echo "Connect with: ssh vagrant@192.168.122.10 (password: vagrant)"
	@echo "Or use VNC: virt-viewer ubuntu-dev"

# List all VMs
list:
	ansible-playbook -i inventory.yml list-vms.yml --ask-become-pass

# Create VM
create:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make create VM=ubuntu-dev"; \
		exit 1; \
	fi
	ansible-playbook -i inventory.yml create-vm.yml -e target_vm=$(VM) --ask-become-pass

# Start VM
start:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make start VM=ubuntu-dev"; \
		exit 1; \
	fi
	ansible-playbook -i inventory.yml manage-vm.yml -e target_vm=$(VM) -e action=start --ask-become-pass

# Stop VM
stop:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make stop VM=ubuntu-dev"; \
		exit 1; \
	fi
	ansible-playbook -i inventory.yml manage-vm.yml -e target_vm=$(VM) -e action=stop --ask-become-pass

# Restart VM
restart:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make restart VM=ubuntu-dev"; \
		exit 1; \
	fi
	ansible-playbook -i inventory.yml manage-vm.yml -e target_vm=$(VM) -e action=restart --ask-become-pass

# Destroy VM
destroy:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make destroy VM=ubuntu-dev"; \
		exit 1; \
	fi
	@echo "WARNING: This will completely destroy the VM and its disk!"
	@read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ]
	ansible-playbook -i inventory.yml destroy-vm.yml -e target_vm=$(VM) --ask-become-pass

# Destroy VM and clean up base image
destroy-all:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make destroy-all VM=ubuntu-dev"; \
		exit 1; \
	fi
	@echo "WARNING: This will destroy the VM AND the shared base image!"
	@echo "This will affect ALL VMs that use the same base image!"
	@read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ]
	ansible-playbook -i inventory.yml destroy-vm.yml -e target_vm=$(VM) -e cleanup_base_image=true --ask-become-pass

# Setup GPU passthrough
gpu-setup:
	ansible-playbook -i inventory.yml setup-gpu-passthrough.yml --ask-become-pass

# Force stop VM
force-stop:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make force-stop VM=ubuntu-dev"; \
		exit 1; \
	fi
	ansible-playbook -i inventory.yml manage-vm.yml -e target_vm=$(VM) -e action=force-stop --ask-become-pass

# SSH into VM using SSH key (default: ubuntu-dev)
ssh:
	@VM_NAME=$(or $(VM),ubuntu-dev); \
	VM_IP=$$(ansible-inventory -i inventory.yml --host $$VM_NAME | grep vm_static_ip | cut -d'"' -f4); \
	if [ -z "$$VM_IP" ]; then \
		echo "Error: Could not find IP address for VM '$$VM_NAME'"; \
		echo "Available VMs:"; \
		ansible-inventory -i inventory.yml --list | grep -E '(ubuntu-dev|ubuntu-gpu)' | head -10; \
		exit 1; \
	fi; \
	if [ ! -f "../secrets/libvirt_vms_ed25519" ]; then \
		echo "Error: SSH key not found. Run 'make setup' first to generate SSH keys."; \
		exit 1; \
	fi; \
	echo "Connecting to $$VM_NAME at $$VM_IP using SSH key..."; \
	ssh -i ../secrets/libvirt_vms_ed25519 \
		-o PreferredAuthentications=publickey \
		-o IdentitiesOnly=yes \
		-o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
		vagrant@$$VM_IP

# SSH into VM using password (default: ubuntu-dev)
ssh-pass:
	@VM_NAME=$(or $(VM),ubuntu-dev); \
	VM_IP=$$(ansible-inventory -i inventory.yml --host $$VM_NAME | grep vm_static_ip | cut -d'"' -f4); \
	if [ -z "$$VM_IP" ]; then \
		echo "Error: Could not find IP address for VM '$$VM_NAME'"; \
		echo "Available VMs:"; \
		ansible-inventory -i inventory.yml --list | grep -E '(ubuntu-dev|ubuntu-gpu)' | head -10; \
		exit 1; \
	fi; \
	echo "Connecting to $$VM_NAME at $$VM_IP using password..."; \
	echo "Password: vagrant"; \
	ssh -o PreferredAuthentications=password \
		-o PubkeyAuthentication=no \
		-o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
		vagrant@$$VM_IP
