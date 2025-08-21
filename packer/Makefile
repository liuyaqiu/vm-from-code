# Ubuntu 24.04 Packer Build Makefile

.PHONY: help install-packer init validate build build-libvirt clean test test-libvirt

# Default target
help:
	@echo "Available targets:"
	@echo "  install-packer - Install HashiCorp Packer automatically"
	@echo "  init           - Initialize Packer plugins (auto-installs Packer if needed)"
	@echo "  validate       - Validate Packer configuration"
	@echo "  build          - Build libvirt image"
	@echo "  build-libvirt  - Build libvirt raw image"
	@echo "  clean          - Clean build artifacts"
	@echo "  test           - Test libvirt image"
	@echo "  test-libvirt   - Test libvirt raw image"
	@echo "  help           - Show this help message"

# Install Packer if not already installed
install-packer:
	@if ! command -v packer >/dev/null 2>&1; then \
		echo "Packer not found. Installing automatically..."; \
		../scripts/install-packer.sh; \
	else \
		echo "Packer is already installed: $$(packer version | head -n1)"; \
	fi

# Initialize Packer plugins (auto-install Packer if needed)
init: install-packer
	packer init ubuntu-24.04.pkr.hcl

# Validate configuration
validate: install-packer
	packer validate ubuntu-24.04.pkr.hcl

# Build libvirt image
build: init validate build-libvirt

# Build libvirt box only
build-libvirt: init validate
	packer build -only='libvirt.*' ubuntu-24.04.pkr.hcl

# Clean build artifacts
clean:
	rm -rf ../output/
	rm -rf ../builds/
	rm -f packer_cache/

# Test libvirt image
test: test-libvirt

# Test libvirt raw image
test-libvirt:
	@if [ ! -f ../builds/ubuntu-24.04-libvirt.qcow2 ]; then \
		echo "Error: libvirt qcow2 image not found. Run 'make build-libvirt' first."; \
		exit 1; \
	fi
	@echo "Raw libvirt image created successfully: ../builds/ubuntu-24.04-libvirt.qcow2"
	@echo "You can now use it with libvirt/virsh:"
	@echo "  # Copy to libvirt images directory"
	@echo "  sudo cp ../builds/ubuntu-24.04-libvirt.qcow2 /var/lib/libvirt/images/"
	@echo "  # Create VM using virt-install or virsh"
	@echo "  # See README for detailed usage instructions"
	qemu-img info ../builds/ubuntu-24.04-libvirt.qcow2

# Debug build - libvirt (headless by default)
debug-libvirt: install-packer
	packer build -only='libvirt.*' ubuntu-24.04.pkr.hcl


