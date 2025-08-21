# Ubuntu 24.04 Packer Variables
# You can override these variables by editing this file or passing them via command line

vm_name = "ubuntu-24.04-server"
disk_size = "40960"  # 40GB
memory = "2048"      # 2GB RAM
cpus = "2"           # 2 CPU cores

source_image_url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
source_image_checksum = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
