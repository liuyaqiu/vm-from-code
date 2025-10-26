# Ansible libvirt VM Management Makefile

.PHONY: help install setup list create start stop restart destroy gpu-setup build-image ssh ssh-pass

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
	@echo "  create VM=name - Create and start VM(s) (supports replicas, e.g., make create VM=ubuntu-dev)"
	@echo "  start VM=name  - Start VM"
	@echo "  stop VM=name   - Stop VM gracefully"
	@echo "  restart VM=name- Restart VM"
	@echo "  destroy VM=name- Destroy VM(s) completely (destroys all replicas)"
	@echo "  destroy-all VM=name - Destroy VM(s) and clean up base image (destroys all replicas + base)"
	@echo "  delete-bridge VM=name - Delete bridge network and restore physical interface"
	@echo "  ssh [VM=name[@idx]]  - SSH into VM using SSH key (e.g., make ssh VM=ubuntu-dev@0)"
	@echo "  ssh-pass [VM=name[@idx]] - SSH into VM using password (e.g., make ssh-pass VM=ubuntu-dev@1)"
	@echo ""
	@echo "  === GPU Features ==="
	@echo "  gpu-setup      - Setup GPU passthrough (see GPU-PASSTHROUGH-AMD.md)"
	@echo ""
	@echo "  === Recommended Usage ==="
	@echo "  1. make install        # First time setup"
	@echo "  2. make setup          # Setup libvirt + static DHCP network"
	@echo "  3. make build-image    # Build clean base image with reset cloud-init"
	@echo "  help           - Show this help message"

# Install Ansible and required collections
install:
	@echo "Installing Ansible and collections..."
	pip3 install ansible
	ansible-galaxy collection install -r requirements.yml

# Setup libvirt environment
setup:
	ansible-playbook -i inventory.yml setup.yml --ask-become-pass

# Build clean base image with Packer (NEW WORKFLOW)
build-image:
	@echo "Building clean Ubuntu base image with Packer..."
	@echo "This image will have reset cloud-init state for deployment flexibility"
	@cd .. && packer build -only=libvirt.qemu.ubuntu ubuntu-24.04.pkr.hcl
	@echo "✅ Clean base image built successfully!"
	@echo "Image location: ../builds/ubuntu-24.04-server.qcow2"
	@echo "Cloud-init state has been reset - ready for deployment-specific configuration"

# List all VMs
list:
	ansible-playbook -i inventory.yml list-vms.yml --ask-become-pass

# Create VM (with replica support)
create:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make create VM=ubuntu-dev"; \
		exit 1; \
	fi
	@echo "Creating VM(s) for $(VM)..."
	@echo "This will create all replicas if configured in inventory.yml"
	ansible-playbook -i inventory.yml create-vm-replicas.yml -e target_vm=$(VM) --ask-become-pass

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

# Destroy VM (with replica support)
destroy:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make destroy VM=ubuntu-dev"; \
		exit 1; \
	fi
	@echo "WARNING: This will completely destroy the VM(s) and disk(s)!"
	@echo "This will destroy all replicas if configured in inventory.yml"
	@read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ]
	ansible-playbook -i inventory.yml destroy-vm-replicas.yml -e target_vm=$(VM) --ask-become-pass

# Destroy VM and clean up base image (with replica support)
destroy-all:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make destroy-all VM=ubuntu-dev"; \
		exit 1; \
	fi
	@echo "WARNING: This will destroy the VM(s) AND the shared base image!"
	@echo "This will destroy all replicas AND affect ALL VMs that use the same base image!"
	@read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ]
	ansible-playbook -i inventory.yml destroy-vm-replicas.yml -e target_vm=$(VM) -e cleanup_base_image=true --ask-become-pass

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

# Delete bridge network
delete-bridge:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make delete-bridge VM=ubuntu-dev"; \
		exit 1; \
	fi
	@echo "WARNING: This will delete the bridge network and restore the physical interface!"
	@read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ]
	ansible-playbook -i inventory.yml manage-vm.yml -e target_vm=$(VM) -e action=delete-bridge --ask-become-pass

# SSH into VM using SSH key (default: ubuntu-dev)
# Supports replica syntax: make ssh VM=ubuntu-dev@0
ssh:
	@VM_SPEC=$(or $(VM),ubuntu-dev); \
	if echo "$$VM_SPEC" | grep -q '@'; then \
		VM_BASE=$$(echo "$$VM_SPEC" | cut -d'@' -f1); \
		VM_INDEX=$$(echo "$$VM_SPEC" | cut -d'@' -f2); \
		VM_NAME="$$VM_BASE-$$VM_INDEX"; \
	else \
		VM_BASE="$$VM_SPEC"; \
		VM_NAME="$$VM_SPEC"; \
	fi; \
	REPLICAS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"replicas":' | grep -oE '[0-9]+' || echo "1"); \
	if [ "$$REPLICAS" -gt 1 ]; then \
		VM_IPS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"vm_static_ips":' -A $$REPLICAS | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo ""); \
		if echo "$$VM_SPEC" | grep -q '@'; then \
			VM_IP=$$(echo "$$VM_IPS" | sed -n "$$((VM_INDEX + 1))p"); \
		else \
			echo "Error: VM '$$VM_BASE' has $$REPLICAS replicas. Please specify which one:"; \
			IDX=0; \
			for IP in $$VM_IPS; do \
				echo "  make ssh VM=$$VM_BASE@$$IDX  # $$VM_BASE-$$IDX ($$IP)"; \
				IDX=$$((IDX + 1)); \
			done; \
			exit 1; \
		fi; \
	else \
		VM_IP=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep vm_static_ip | cut -d'"' -f4); \
	fi; \
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
# Supports replica syntax: make ssh-pass VM=ubuntu-dev@0
ssh-pass:
	@VM_SPEC=$(or $(VM),ubuntu-dev); \
	if echo "$$VM_SPEC" | grep -q '@'; then \
		VM_BASE=$$(echo "$$VM_SPEC" | cut -d'@' -f1); \
		VM_INDEX=$$(echo "$$VM_SPEC" | cut -d'@' -f2); \
		VM_NAME="$$VM_BASE-$$VM_INDEX"; \
	else \
		VM_BASE="$$VM_SPEC"; \
		VM_NAME="$$VM_SPEC"; \
	fi; \
	REPLICAS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"replicas":' | grep -oE '[0-9]+' || echo "1"); \
	if [ "$$REPLICAS" -gt 1 ]; then \
		VM_IPS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"vm_static_ips":' -A $$REPLICAS | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo ""); \
		if echo "$$VM_SPEC" | grep -q '@'; then \
			VM_IP=$$(echo "$$VM_IPS" | sed -n "$$((VM_INDEX + 1))p"); \
		else \
			echo "Error: VM '$$VM_BASE' has $$REPLICAS replicas. Please specify which one:"; \
			IDX=0; \
			for IP in $$VM_IPS; do \
				echo "  make ssh-pass VM=$$VM_BASE@$$IDX  # $$VM_BASE-$$IDX ($$IP)"; \
				IDX=$$((IDX + 1)); \
			done; \
			exit 1; \
		fi; \
	else \
		VM_IP=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep vm_static_ip | cut -d'"' -f4); \
	fi; \
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
