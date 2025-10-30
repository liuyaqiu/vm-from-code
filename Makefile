# Root Makefile for learn-packer project
# This delegates to both packer and ansible subdirectories

.PHONY: help install setup packer-help ansible-help clean

# Default target
help:
	@echo "VM from Code - Multi-tool VM Management Project"
	@echo ""
	@echo "Available targets:"
	@echo "  help           - Show this help message"
	@echo "  install        - Install build dependencies (Packer)"
	@echo "  setup          - Complete setup (build + runtime dependencies)"
	@echo "  packer-help    - Show packer-specific targets"
	@echo "  ansible-help   - Show ansible-specific targets"
	@echo "  clean          - Clean all build artifacts"
	@echo ""
	@echo "=== QUICK START ==="
	@echo "  make setup     - One-command setup (installs everything)"
	@echo "  make build     - Build VM image"
	@echo ""
	@echo "=== PACKER TARGETS (Image Building) ==="
	@echo "  packer-install - Install Packer automatically"
	@echo "  packer-init    - Initialize Packer plugins"
	@echo "  packer-validate- Validate Packer configuration"
	@echo "  packer-build   - Build libvirt image"
	@echo "  packer-build-libvirt - Build libvirt image"
	@echo "  packer-test    - Test built image"
	@echo ""
	@echo "=== ANSIBLE TARGETS (Runtime Environment) ==="
	@echo "  ansible-setup    - Install runtime dependencies (QEMU/KVM)"
	@echo "  ansible-list     - List available libvirt VMs"
	@echo "  ansible-list-pve - List available Proxmox VE VMs"
	@echo "  ansible-create   - Create VMs (specify VM with target_vm=name)"
	@echo "  ansible-destroy  - Destroy VMs (specify VM with target_vm=name)"
	@echo ""
	@echo "For detailed help on specific tools:"
	@echo "  make packer-help"
	@echo "  make ansible-help"

# Show packer-specific help
packer-help:
	@echo "=== PACKER TARGETS ==="
	@cd packer && make help

# Show ansible-specific help  
ansible-help:
	@echo "=== ANSIBLE TARGETS ==="
	@cd ansible && make help



# Clean all artifacts
clean:
	@echo "Cleaning packer artifacts..."
	@cd packer && make clean || true
	@echo "Cleaning ansible artifacts..."
	@cd ansible && make clean || true
	@echo "Clean complete."

# === INSTALLATION TARGETS ===
mise-setup:
	@echo "Setting up mise..."
	@mise install
	@mise run install-deps
	@echo "✅ Mise setup complete!"

# Complete setup: install build tools + setup runtime environment
setup: mise-setup packer-init
	@echo "✅ Complete setup finished! You can now run 'make build'"

# === PACKER DELEGATION TARGETS ===
packer-install:
	@cd packer && make install-packer

packer-init:
	@cd packer && make init

packer-validate:
	@cd packer && make validate

packer-build:
	@cd packer && make build

packer-build-libvirt:
	@cd packer && make build-libvirt

packer-test:
	@cd packer && make test

packer-test-libvirt:
	@cd packer && make test-libvirt

packer-debug-libvirt:
	@cd packer && make debug-libvirt

# === ANSIBLE DELEGATION TARGETS ===
ansible-setup:
	@cd ansible && make setup

ansible-list:
	@cd ansible && make list

ansible-list-pve:
	@cd ansible && make list-pve

ansible-create:
	@cd ansible && make create target_vm=$(target_vm)

ansible-destroy:
	@cd ansible && make destroy target_vm=$(target_vm)

ansible-manage:
	@cd ansible && make manage target_vm=$(target_vm)



# === COMBINED WORKFLOWS ===
# Quick build (auto-installs if needed)
build: packer-build-libvirt

# Build images and then create VMs
workflow-build-and-create: packer-build-libvirt ansible-create
	@echo "✅ Images built and VM created successfully!"

# Full cleanup - destroy VMs and clean artifacts
workflow-full-clean: ansible-destroy clean
	@echo "✅ Full cleanup completed!"
