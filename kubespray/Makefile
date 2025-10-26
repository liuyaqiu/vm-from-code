# Kubespray Docker Management Makefile

# Configuration variables
INVENTORY_PATH := $(CURDIR)/inventory
SSH_PRIVATE_KEY_PATH := $(CURDIR)/../secrets/libvirt_vms_ed25519
KUBE_CONFIG_PATH := $(CURDIR)/../secrets/kube.config
KUBESPRAY_VERSION := v2.29.0
CUSTOM_IMAGE_NAME := kubespray-custom
CUSTOM_IMAGE_TAG := $(KUBESPRAY_VERSION)

.PHONY: help bash docker-build

# Default target
help:
	@echo "Available targets:"
	@echo ""
	@echo "  docker-build   - Build custom Kubespray Docker image from Dockerfile"
	@echo "  bash           - Start Kubespray Docker container with interactive bash"
	@echo ""
	@echo "Configuration:"
	@echo "  INVENTORY_PATH: $(INVENTORY_PATH)"
	@echo "  SSH_PRIVATE_KEY_PATH: $(SSH_PRIVATE_KEY_PATH)"
	@echo "  KUBE_CONFIG_PATH: $(KUBE_CONFIG_PATH)"
	@echo "  KUBESPRAY_VERSION: $(KUBESPRAY_VERSION)"
	@echo "  CUSTOM_IMAGE_NAME: $(CUSTOM_IMAGE_NAME)"
	@echo "  CUSTOM_IMAGE_TAG: $(CUSTOM_IMAGE_TAG)"

# Build custom Kubespray Docker image
docker-build:
	@echo "Building custom Kubespray Docker image..."
	@echo "Base image: quay.io/kubespray/kubespray:$(KUBESPRAY_VERSION)"
	@echo "Custom image: $(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG)"
	docker build \
		--build-arg KUBESPRAY_VERSION=$(KUBESPRAY_VERSION) \
		-t $(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG) \
		-t $(CUSTOM_IMAGE_NAME):latest \
		.
	@echo "✅ Custom image built successfully!"
	@echo "Image: $(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG)"

# Start Kubespray Docker container with interactive bash
bash: docker-build
	@echo "Starting Kubespray Docker container..."
	@echo "Inventory: $(INVENTORY_PATH)"
	@echo "SSH Key: $(SSH_PRIVATE_KEY_PATH)"
	@echo "Kube Config: $(KUBE_CONFIG_PATH)"
	@echo "Using custom image: $(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG)"
	docker run --rm -it \
		--mount type=bind,source=$(INVENTORY_PATH),dst=/inventory \
		--mount type=bind,source=$(SSH_PRIVATE_KEY_PATH),dst=/root/.ssh/id_rsa \
		--mount type=bind,source=$(KUBE_CONFIG_PATH),dst=/root/.kube/config \
		$(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG) bash