# Kubespray Docker Management Makefile

# Configuration variables
INVENTORY_PATH := $(CURDIR)/inventory
SSH_PRIVATE_KEY_PATH := $(CURDIR)/../secrets/libvirt_vms_ed25519
KUBESPRAY_VERSION := v2.29.0
CUSTOM_IMAGE_NAME := kubespray-custom
CUSTOM_IMAGE_TAG := $(KUBESPRAY_VERSION)
REMOVED_NODES := nodename,nodename2
MASTER_NODE := vagrant@192.168.88.10
KUBECONFIG_PATH := $(INVENTORY_PATH)/artifacts/admin.conf
CONFIGS := $(CURDIR)/configs
EXPERIMENTS_PATH := $(CURDIR)/experiments

.PHONY: help bash docker-build install add-node remove-node proxy

# Default target
help:
	@echo "Available targets:"
	@echo ""
	@echo "  docker-build       - Build custom Kubespray Docker image from Dockerfile"
	@echo "  bash               - Start Kubespray Docker container with interactive bash"
	@echo "  install            - Run Kubespray cluster installation using cluster.yml"
	@echo "  add-node 	        - Add nodes into the existing cluster using scale.yml"
	@echo "  remove-node 	    - Remove nodes from the existing cluster using remove-nodes.yml"
	@echo "  proxy              - Create SSH tunnel to proxy master node port 8001 to localhost:8001"
	@echo ""
	@echo "Configuration:"
	@echo "  INVENTORY_PATH: $(INVENTORY_PATH)"
	@echo "  SSH_PRIVATE_KEY_PATH: $(SSH_PRIVATE_KEY_PATH)"
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
	@echo "Kubeconfig: $(KUBECONFIG_PATH)"
	@echo "Using custom image: $(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG)"
	@echo "Experiments path: $(EXPERIMENTS_PATH)"
	mkdir -p $(EXPERIMENTS_PATH)
	docker run -w /root/experiments --rm -it \
		--mount type=bind,source=$(KUBECONFIG_PATH),dst=/root/.kube/config \
		--mount type=bind,source=$(CONFIGS),dst=/root/configs \
		--mount type=bind,source=$(EXPERIMENTS_PATH),dst=/root/experiments \
		$(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG) bash

# Run Kubespray cluster installation
install: docker-build
	@echo "Running Kubespray cluster installation..."
	@echo "Inventory: $(INVENTORY_PATH)"
	@echo "SSH Key: $(SSH_PRIVATE_KEY_PATH)"
	@echo "Using custom image: $(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG)"
	docker run --rm -it \
		--mount type=bind,source=$(INVENTORY_PATH),dst=/inventory \
		--mount type=bind,source=$(SSH_PRIVATE_KEY_PATH),dst=/root/.ssh/id_rsa \
		$(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG) \
		ansible-playbook -i /inventory/inventory.ini --user vagrant --private-key /root/.ssh/id_rsa --become cluster.yml

# Add nodes into Kubespray cluster
add-node: docker-build
	@echo "Running Kubespray cluster installation..."
	@echo "Inventory: $(INVENTORY_PATH)"
	@echo "SSH Key: $(SSH_PRIVATE_KEY_PATH)"
	@echo "Using custom image: $(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG)"
	docker run --rm -it \
		--mount type=bind,source=$(INVENTORY_PATH),dst=/inventory \
		--mount type=bind,source=$(SSH_PRIVATE_KEY_PATH),dst=/root/.ssh/id_rsa \
		$(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG) \
		ansible-playbook -i /inventory/inventory.ini --user vagrant --private-key /root/.ssh/id_rsa --become scale.yml

# Remove nodes from Kubespray cluster
remove-node: docker-build
	@echo "Running Kubespray cluster installation..."
	@echo "Inventory: $(INVENTORY_PATH)"
	@echo "SSH Key: $(SSH_PRIVATE_KEY_PATH)"
	@echo "Using custom image: $(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG)"
	docker run --rm -it \
		--mount type=bind,source=$(INVENTORY_PATH),dst=/inventory \
		--mount type=bind,source=$(SSH_PRIVATE_KEY_PATH),dst=/root/.ssh/id_rsa \
		$(CUSTOM_IMAGE_NAME):$(CUSTOM_IMAGE_TAG) \
		ansible-playbook -i /inventory/inventory.ini --user vagrant \
		--private-key /root/.ssh/id_rsa --become remove-node.yml \
		--extra-vars "node=$(REMOVED_NODES)"

# Create SSH tunnel to proxy master node port 8001 to localhost:8001
proxy:
	@echo "Creating SSH tunnel to master node..."
	@echo "Master Node: $(MASTER_NODE)"
	@echo "SSH Key: $(SSH_PRIVATE_KEY_PATH)"
	@echo "Proxying $(MASTER_NODE):8001 -> localhost:8001"
	@echo "Press Ctrl+C to stop the tunnel"
	ssh -i $(SSH_PRIVATE_KEY_PATH) -L 8001:localhost:8001 -N $(MASTER_NODE)

