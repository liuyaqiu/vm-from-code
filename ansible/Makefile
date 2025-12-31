# Ansible Multi-Provider VM Management Makefile
# Supports both libvirt (local) and Proxmox VE (remote) provisioners

.PHONY: help install setup cleanup list list-pve create start stop restart destroy gpu-setup build-image ssh ssh-pass
.PHONY: setup-pve create-pve destroy-pve load-secrets cleanup-secrets fix-pci-bus

# Vault password file for PVE encrypted credentials
PVE_VAULT_PASS_FILE = $(HOME)/.ansible/pve-vault-pass

# Default target
help:
	@echo "Available targets:"
	@echo ""
	@echo "  === Setup ==="
	@echo "  install        - Install Ansible and required collections"
	@echo "  setup          - Setup libvirt environment (local)"
	@echo "  cleanup        - Cleanup bridge network and QEMU config (checks VM dependencies)"
	@echo "  setup-pve      - Setup PVE: configure SSH keys + upload base image (prompts for password on first run)"
	@echo ""
	@echo "  === Image Building ==="
	@echo "  build-image    - Build Ubuntu cloud image with Packer (fast!)"
	@echo ""
	@echo "  === VM Management (Auto-detects provisioner: libvirt/pve/terraform) ==="
	@echo "  list           - List all libvirt VMs and their status"
	@echo "  list-pve       - List all Proxmox VE VMs and their status"
	@echo "  create VM=name - Create and start VM(s) (supports replicas, auto-detects provisioner)"
	@echo "  destroy VM=name[@idx] - Destroy VM(s) (terraform: all replicas only; others: single/@idx supported)"
	@echo ""
	@echo "  === Libvirt-specific Management ==="
	@echo "  start VM=name  - Start VM"
	@echo "  stop VM=name   - Stop VM gracefully"
	@echo "  restart VM=name- Restart VM"
	@echo "  destroy-all VM=name - Destroy VM(s) and clean up base image (destroys all replicas + base)"
	@echo "  gpu-setup      - Setup GPU passthrough (see GPU-PASSTHROUGH-AMD.md)"
	@echo "  fix-pci-bus VM=name[@idx] - Fix PCI bus ordering for VMs (all replicas if @idx omitted)"
	@echo ""
	@echo "  === SSH Access (Works for both provisioners) ==="
	@echo "  ssh [VM=name[@idx]]  - SSH into VM using SSH key (e.g., make ssh VM=ubuntu-dev@0)"
	@echo "  ssh-pass [VM=name[@idx]] - SSH into VM using password (e.g., make ssh-pass VM=ubuntu-dev@1)"
	@echo ""
	@echo "  === Secret Management ==="
	@echo "  load-secrets   - Decrypt encrypted secrets (*.encrypted -> plain files)"
	@echo "  cleanup-secrets- Remove decrypted secrets (keep only *.encrypted files)"
	@echo ""
	@echo "  === Examples ==="
	@echo "  Libvirt:  make create VM=k8s-master      # Creates libvirt VMs"
	@echo "  PVE:      make create VM=k8s-master-pve  # Creates PVE VMs"
	@echo "  SSH:      make ssh VM=k8s-master@0       # SSH to first replica"
	@echo ""
	@echo "  === Recommended Usage ==="
	@echo "  1. make install        # First time setup"
	@echo "  2. make setup          # Setup libvirt + static DHCP network"
	@echo "  3. make build-image    # Build clean base image with reset cloud-init"
	@echo "  4. make setup-pve      # (Optional) Setup PVE and upload image"
	@echo "  help           - Show this help message"

# Install Ansible and required collections
install:
	@echo "Installing Ansible and collections..."
	pip3 install ansible
	ansible-galaxy collection install -r requirements.yml

# Setup libvirt environment
setup:
	ansible-playbook -i inventory.yml setup.yml --ask-become-pass

# Cleanup bridge network and QEMU configuration
cleanup:
	@echo "WARNING: This will remove bridge network and QEMU bridge configuration!"
	@echo "All VMs using the bridge must be destroyed first."
	@read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ]
	ansible-playbook -i inventory.yml setup.yml --tags cleanup --ask-become-pass

# Setup Proxmox VE environment and upload base image
setup-pve:
	@echo "Setting up Proxmox VE environment..."
	@if [ ! -f ../builds/ubuntu-24.04-libvirt.qcow2 ]; then \
		echo "Error: Base image not found. Please run 'make build-image' first."; \
		exit 1; \
	fi
	@if [ ! -f "$(PVE_VAULT_PASS_FILE)" ]; then \
		echo "Error: Vault password file not found at $(PVE_VAULT_PASS_FILE)"; \
		echo "Please create it or use --ask-vault-pass manually"; \
		exit 1; \
	fi
	ansible-playbook -i inventory.yml setup-pve.yml --vault-password-file $(PVE_VAULT_PASS_FILE)

# Build clean base image with Packer (NEW WORKFLOW)
build-image:
	@echo "Building clean Ubuntu base image with Packer..."
	@echo "This image will have reset cloud-init state for deployment flexibility"
	@cd .. && packer build -only=libvirt.qemu.ubuntu ubuntu-24.04.pkr.hcl
	@echo "✅ Clean base image built successfully!"
	@echo "Image location: ../builds/ubuntu-24.04-server.qcow2"
	@echo "Cloud-init state has been reset - ready for deployment-specific configuration"

# Load encrypted secrets (decrypt *.encrypted files)
load-secrets:
	@echo "Loading encrypted secrets..."
	@if [ ! -f "$(PVE_VAULT_PASS_FILE)" ]; then \
		echo "Warning: Vault password file not found at $(PVE_VAULT_PASS_FILE)"; \
		echo "Secrets requiring vault password will not be decrypted"; \
	else \
		ansible-playbook load-secrets.yml --vault-password-file $(PVE_VAULT_PASS_FILE); \
	fi

# Cleanup decrypted secrets (remove plain files, keep *.encrypted)
cleanup-secrets:
	@echo "Cleaning up decrypted secrets..."
	@if [ ! -f "$(PVE_VAULT_PASS_FILE)" ]; then \
		echo "Warning: Vault password file not found at $(PVE_VAULT_PASS_FILE)"; \
	else \
		ansible-playbook load-secrets.yml -e cleanup=true --vault-password-file $(PVE_VAULT_PASS_FILE); \
	fi

# List all libvirt VMs
list:
	ansible-playbook -i inventory.yml list-vms.yml

# List all PVE VMs
list-pve: load-secrets
	@if [ ! -f "$(PVE_VAULT_PASS_FILE)" ]; then \
		echo "Error: Vault password file not found at $(PVE_VAULT_PASS_FILE)"; \
		echo "Please create it or use --ask-vault-pass manually"; \
		exit 1; \
	fi
	ansible-playbook -i inventory.yml list-vms-pve.yml --vault-password-file $(PVE_VAULT_PASS_FILE)

# Create VM (with replica support) - Auto-detects provisioner
create: load-secrets
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make create VM=ubuntu-dev"; \
		exit 1; \
	fi
	@echo "Detecting provisioner for $(VM)..."
	@PROVISIONER=$$(ansible-inventory -i inventory.yml --host $(VM) 2>/dev/null | grep -E '"provisioner":' | grep -oE '(libvirt|pve|terraform)' || echo "libvirt"); \
	echo "Provisioner: $$PROVISIONER"; \
	if [ "$$PROVISIONER" = "pve" ]; then \
		echo "Creating PVE VM(s) for $(VM)..."; \
		echo "This will create all replicas if configured in inventory.yml"; \
		if [ ! -f "$(PVE_VAULT_PASS_FILE)" ]; then \
			echo "Error: Vault password file not found at $(PVE_VAULT_PASS_FILE)"; \
			echo "Please create it or use --ask-vault-pass manually"; \
			exit 1; \
		fi; \
		ansible-playbook -i inventory.yml create-vm-replicas-pve.yml -e target_vm=$(VM) --vault-password-file $(PVE_VAULT_PASS_FILE); \
	elif [ "$$PROVISIONER" = "terraform" ]; then \
		echo "Creating Terraform VM(s) for $(VM)..."; \
		echo "This will create all replicas if configured in inventory.yml"; \
		ansible-playbook -i inventory.yml create-vm-replicas-terraform.yml -e target_vm=$(VM); \
	else \
		echo "Creating libvirt VM(s) for $(VM)..."; \
		echo "This will create all replicas if configured in inventory.yml"; \
		ansible-playbook -i inventory.yml create-vm-replicas.yml -e target_vm=$(VM); \
	fi

# Start VM
start:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make start VM=ubuntu-dev"; \
		exit 1; \
	fi
	ansible-playbook -i inventory.yml manage-vm.yml -e target_vm=$(VM) -e action=start

# Stop VM
stop:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make stop VM=ubuntu-dev"; \
		exit 1; \
	fi
	ansible-playbook -i inventory.yml manage-vm.yml -e target_vm=$(VM) -e action=stop

# Restart VM
restart:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make restart VM=ubuntu-dev"; \
		exit 1; \
	fi
	ansible-playbook -i inventory.yml manage-vm.yml -e target_vm=$(VM) -e action=restart

# Destroy VM (with replica support) - Auto-detects provisioner
# Usage: make destroy VM=name      (destroy all replicas)
#        make destroy VM=name@idx  (destroy single replica)
destroy: load-secrets
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make destroy VM=ubuntu-dev[@0]"; \
		exit 1; \
	fi
	@VM_SPEC=$(VM); \
	if echo "$$VM_SPEC" | grep -q '@'; then \
		VM_BASE=$$(echo "$$VM_SPEC" | cut -d'@' -f1); \
		VM_INDEX=$$(echo "$$VM_SPEC" | cut -d'@' -f2); \
		VM_NAME="$$VM_BASE-$$VM_INDEX"; \
		echo "WARNING: This will completely destroy $$VM_NAME and its disk!"; \
		read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ]; \
		PROVISIONER=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"provisioner":' | grep -oE '(libvirt|pve|terraform)' || echo "libvirt"); \
		echo "Provisioner: $$PROVISIONER"; \
		if [ "$$PROVISIONER" = "pve" ]; then \
			echo "Destroying PVE VM $$VM_NAME..."; \
			if [ ! -f "$(PVE_VAULT_PASS_FILE)" ]; then \
				echo "Error: Vault password file not found at $(PVE_VAULT_PASS_FILE)"; \
				echo "Please create it or use --ask-vault-pass manually"; \
				exit 1; \
			fi; \
			ansible-playbook -i inventory.yml destroy-single-vm-pve.yml -e target_vm=$$VM_BASE -e replica_index=$$VM_INDEX --vault-password-file $(PVE_VAULT_PASS_FILE); \
		elif [ "$$PROVISIONER" = "terraform" ]; then \
			echo "Error: Terraform VMs must be destroyed using 'make destroy VM=$$VM_BASE' (without @idx) to destroy all replicas."; \
			echo "Terraform manages all replicas together and cannot destroy individual replicas."; \
			exit 1; \
		else \
			echo "Destroying libvirt VM $$VM_NAME..."; \
			ansible-playbook -i inventory.yml destroy-single-vm.yml -e target_vm=$$VM_BASE -e replica_index=$$VM_INDEX; \
		fi; \
	else \
		VM_BASE="$$VM_SPEC"; \
		echo "WARNING: This will completely destroy all replicas of $$VM_BASE and their disks!"; \
		REPLICAS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"replicas":' | grep -oE '[0-9]+' || echo "1"); \
		echo "This will destroy $$REPLICAS replica(s)"; \
		read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ]; \
		PROVISIONER=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"provisioner":' | grep -oE '(libvirt|pve|terraform)' || echo "libvirt"); \
		echo "Provisioner: $$PROVISIONER"; \
		if [ "$$PROVISIONER" = "pve" ]; then \
			echo "Destroying PVE VM(s) for $$VM_BASE..."; \
			if [ ! -f "$(PVE_VAULT_PASS_FILE)" ]; then \
				echo "Error: Vault password file not found at $(PVE_VAULT_PASS_FILE)"; \
				echo "Please create it or use --ask-vault-pass manually"; \
				exit 1; \
			fi; \
			ansible-playbook -i inventory.yml destroy-vm-replicas-pve.yml -e target_vm=$$VM_BASE --vault-password-file $(PVE_VAULT_PASS_FILE); \
		elif [ "$$PROVISIONER" = "terraform" ]; then \
			echo "Destroying Terraform VM(s) for $$VM_BASE..."; \
			ansible-playbook -i inventory.yml destroy-vm-replicas-terraform.yml -e target_vm=$$VM_BASE; \
		else \
			echo "Destroying libvirt VM(s) for $$VM_BASE..."; \
			ansible-playbook -i inventory.yml destroy-vm-replicas.yml -e target_vm=$$VM_BASE; \
		fi; \
	fi

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
	ansible-playbook -i inventory.yml manage-vm.yml -e target_vm=$(VM) -e action=force-stop

# SSH into VM using SSH key (default: ubuntu-dev@0)
# Requires replica syntax: make ssh VM=ubuntu-dev@0
# Auto-detects provisioner (libvirt or pve) from inventory
ssh:
	@VM_SPEC=$(or $(VM),ubuntu-dev@0); \
	if echo "$$VM_SPEC" | grep -q '@'; then \
		VM_BASE=$$(echo "$$VM_SPEC" | cut -d'@' -f1); \
		VM_INDEX=$$(echo "$$VM_SPEC" | cut -d'@' -f2); \
		VM_NAME="$$VM_BASE-$$VM_INDEX"; \
	else \
		echo "Error: Please specify replica index. Usage: make ssh VM=$$VM_SPEC@0"; \
		VM_BASE="$$VM_SPEC"; \
		REPLICAS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"replicas":' | grep -oE '[0-9]+' || echo "1"); \
		VM_IPS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"vm_static_ips":' -A $$REPLICAS | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo ""); \
		echo "Available replicas for '$$VM_BASE':"; \
		IDX=0; \
		for IP in $$VM_IPS; do \
			echo "  make ssh VM=$$VM_BASE@$$IDX  # $$VM_BASE-$$IDX ($$IP)"; \
			IDX=$$((IDX + 1)); \
		done; \
		exit 1; \
	fi; \
	PROVISIONER=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"provisioner":' | grep -oE '(libvirt|pve)' || echo "libvirt"); \
	REPLICAS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"replicas":' | grep -oE '[0-9]+' || echo "1"); \
	VM_IPS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"vm_static_ips":' -A $$REPLICAS | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo ""); \
	VM_IP=$$(echo "$$VM_IPS" | sed -n "$$((VM_INDEX + 1))p"); \
	if [ -z "$$VM_IP" ]; then \
		echo "Error: Could not find IP address for VM '$$VM_NAME' (index $$VM_INDEX)"; \
		echo "Available replicas:"; \
		IDX=0; \
		for IP in $$VM_IPS; do \
			echo "  $$VM_BASE@$$IDX -> $$VM_BASE-$$IDX ($$IP)"; \
			IDX=$$((IDX + 1)); \
		done; \
		exit 1; \
	fi; \
	if [ ! -f "../secrets/libvirt_vms_ed25519" ]; then \
		echo "Error: SSH key not found. Run 'make setup' first to generate SSH keys."; \
		exit 1; \
	fi; \
	echo "Connecting to $$VM_NAME ($$PROVISIONER) at $$VM_IP using SSH key..."; \
	ssh -i ../secrets/libvirt_vms_ed25519 \
		-o PreferredAuthentications=publickey \
		-o IdentitiesOnly=yes \
		-o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
		vagrant@$$VM_IP

# SSH into VM using password (default: ubuntu-dev@0)
# Requires replica syntax: make ssh-pass VM=ubuntu-dev@0
# Auto-detects provisioner (libvirt or pve) from inventory
ssh-pass:
	@VM_SPEC=$(or $(VM),ubuntu-dev@0); \
	if echo "$$VM_SPEC" | grep -q '@'; then \
		VM_BASE=$$(echo "$$VM_SPEC" | cut -d'@' -f1); \
		VM_INDEX=$$(echo "$$VM_SPEC" | cut -d'@' -f2); \
		VM_NAME="$$VM_BASE-$$VM_INDEX"; \
	else \
		echo "Error: Please specify replica index. Usage: make ssh-pass VM=$$VM_SPEC@0"; \
		VM_BASE="$$VM_SPEC"; \
		REPLICAS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"replicas":' | grep -oE '[0-9]+' || echo "1"); \
		VM_IPS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"vm_static_ips":' -A $$REPLICAS | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo ""); \
		echo "Available replicas for '$$VM_BASE':"; \
		IDX=0; \
		for IP in $$VM_IPS; do \
			echo "  make ssh-pass VM=$$VM_BASE@$$IDX  # $$VM_BASE-$$IDX ($$IP)"; \
			IDX=$$((IDX + 1)); \
		done; \
		exit 1; \
	fi; \
	PROVISIONER=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"provisioner":' | grep -oE '(libvirt|pve)' || echo "libvirt"); \
	REPLICAS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"replicas":' | grep -oE '[0-9]+' || echo "1"); \
	VM_IPS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"vm_static_ips":' -A $$REPLICAS | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo ""); \
	VM_IP=$$(echo "$$VM_IPS" | sed -n "$$((VM_INDEX + 1))p"); \
	if [ -z "$$VM_IP" ]; then \
		echo "Error: Could not find IP address for VM '$$VM_NAME' (index $$VM_INDEX)"; \
		echo "Available replicas:"; \
		IDX=0; \
		for IP in $$VM_IPS; do \
			echo "  $$VM_BASE@$$IDX -> $$VM_BASE-$$IDX ($$IP)"; \
			IDX=$$((IDX + 1)); \
		done; \
		exit 1; \
	fi; \
	echo "Connecting to $$VM_NAME ($$PROVISIONER) at $$VM_IP using password..."; \
	echo "Password: vagrant"; \
	ssh -o PreferredAuthentications=password \
		-o PubkeyAuthentication=no \
		-o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
		vagrant@$$VM_IP

# Fix PCI bus ordering issue (filesystem on bus 0x01, network on 0x02)
# This swaps them so network is on 0x01 and filesystem is on 0x02+
# Usage: make fix-pci-bus VM=name@idx  (single replica)
#        make fix-pci-bus VM=name      (all replicas)
# Note: Works for libvirt and terraform provisioners (both use libvirt backend)
fix-pci-bus:
	@if [ -z "$(VM)" ]; then \
		echo "Error: Please specify VM name. Usage: make fix-pci-bus VM=terraform-test[@0]"; \
		exit 1; \
	fi
	@VM_SPEC=$(VM); \
	VM_BASE=$$(echo "$$VM_SPEC" | cut -d'@' -f1); \
	PROVISIONER=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"provisioner":' | grep -oE '(libvirt|pve|terraform)' || echo "libvirt"); \
	if [ "$$PROVISIONER" = "pve" ]; then \
		echo "Error: PCI bus fix is not supported for PVE provisioner."; \
		echo "This operation only works with libvirt and terraform provisioners."; \
		exit 1; \
	fi; \
	if echo "$$VM_SPEC" | grep -q '@'; then \
		VM_INDEX=$$(echo "$$VM_SPEC" | cut -d'@' -f2); \
		VM_NAME="$$VM_BASE-$$VM_INDEX"; \
		echo "Fixing PCI bus ordering for $$VM_NAME ($$PROVISIONER provisioner, single replica)..."; \
		echo "This will:"; \
		echo "  1. Dump current VM XML"; \
		echo "  2. Destroy the VM"; \
		echo "  3. Delete the VM disk"; \
		echo "  4. Fix XML (network -> bus 0x01, filesystem -> bus 0x02)"; \
		echo "  5. Recreate disk and VM with fixed XML"; \
		read -p "Continue? (y/N) " confirm && [ "$$confirm" = "y" ]; \
		ansible-playbook -i inventory.yml fix-vm-pci-bus.yml -e target_vm=$$VM_BASE -e replica_index=$$VM_INDEX; \
	else \
		REPLICAS=$$(ansible-inventory -i inventory.yml --host $$VM_BASE 2>/dev/null | grep -E '"replicas":' | grep -oE '[0-9]+' || echo "1"); \
		echo "Fixing PCI bus ordering for all replicas of $$VM_BASE ($$PROVISIONER provisioner, $$REPLICAS replica(s))..."; \
		echo "This will:"; \
		echo "  1. Dump current VM XML for each replica"; \
		echo "  2. Destroy each VM"; \
		echo "  3. Delete each VM disk"; \
		echo "  4. Fix XML (network -> bus 0x01, filesystem -> bus 0x02)"; \
		echo "  5. Recreate disk and VM with fixed XML"; \
		read -p "Continue? (y/N) " confirm && [ "$$confirm" = "y" ]; \
		for i in $$(seq 0 $$((REPLICAS - 1))); do \
			echo ""; \
			echo "Processing replica $$i of $$((REPLICAS))..."; \
			ansible-playbook -i inventory.yml fix-vm-pci-bus.yml -e target_vm=$$VM_BASE -e replica_index=$$i || { \
				echo "Error processing replica $$i, continuing with next replica..."; \
			}; \
		done; \
		echo ""; \
		echo "✅ Finished processing all replicas of $$VM_BASE"; \
	fi
