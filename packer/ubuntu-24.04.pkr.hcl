packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"
  default     = "ubuntu-24.04-server"
}

variable "disk_size" {
  type        = string
  description = "Size of the disk in MB"
  default     = "40960"
}

variable "memory" {
  type        = string
  description = "Amount of memory in MB"
  default     = "2048"
}

variable "cpus" {
  type        = string
  description = "Number of CPUs"
  default     = "2"
}

variable "source_image_url" {
  type        = string
  description = "URL to the Ubuntu 24.04 cloud image"
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "source_image_checksum" {
  type        = string
  description = "SHA256 checksum of the cloud image"
  default     = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
}


source "qemu" "ubuntu" {
  vm_name          = var.vm_name
  
  # Cloud image configuration
  disk_image       = true
  iso_url          = var.source_image_url
  iso_checksum     = var.source_image_checksum
  
  # Hardware configuration
  disk_size        = var.disk_size
  memory           = var.memory
  cpus             = var.cpus
  
  # QEMU specific settings
  accelerator      = "kvm"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  
  # Network configuration
  headless         = true
  
  # SSH configuration - we'll use vagrant user after cloud-init sets it up
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout     = "20m"
  ssh_handshake_attempts = 100
  ssh_wait_timeout = "20m"
  ssh_pty          = true
  
  # Cloud-init configuration
  cd_files = [
    "cloud-init/user-data",
    "cloud-init/meta-data"
  ]
  cd_label = "cidata"
  
  # Output configuration
  output_directory = "../output/qemu"
  
  # Shutdown command
  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"
}




# Build for libvirt/QEMU - outputs raw qcow2 image
build {
  name = "libvirt"
  sources = ["source.qemu.ubuntu"]
  
  # Wait for cloud-init to complete
  provisioner "shell" {
    pause_before = "60s"  # Give more time for cloud-init
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "timeout 300 cloud-init status --wait || echo 'Cloud-init timeout, continuing anyway'",
      "echo 'Cloud-init status:'",
      "cloud-init status --long || true",
      "echo 'System ready!'",
      "echo 'Checking vagrant user...'",
      "id vagrant || echo 'vagrant user not found'",
      "echo 'Checking network configuration...'",
      "ip addr show || ifconfig || echo 'Network info not available'"
    ]
  }
  
  # Update system and install packages
  provisioner "shell" {
    script = "scripts/provision.sh"
  }
  
  # Reset cloud-init state and ensure NoCloud datasource is enabled
  provisioner "shell" {
    inline = [
      "echo 'Resetting cloud-init state for deployment...'",
      "sudo cloud-init clean --logs",
      "sudo rm -rf /var/lib/cloud/instances/*",
      "sudo rm -rf /var/lib/cloud/instance",
      "sudo rm -rf /var/log/cloud-init*",
      "sudo rm -rf /etc/netplan/50-cloud-init.yaml",
      "sudo rm -rf /etc/netplan/*cloud-init*",
    ]
  }
  
  # Cleanup
  provisioner "shell" {
    script = "scripts/cleanup.sh"
  }
  
  # Copy the qcow2 image to builds directory (no Vagrant packaging)
  post-processor "shell-local" {
    inline = [
      "mkdir -p ../builds",
      "mv ../output/qemu/ubuntu-24.04-server ../builds/ubuntu-24.04-libvirt.qcow2",
      "echo 'Raw libvirt image created: ../builds/ubuntu-24.04-libvirt.qcow2'"
    ]
  }
}
