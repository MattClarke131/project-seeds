resource "proxmox_virtual_environment_vm" "home_assistant" {
  name      = "home-assistant"
  node_name = var.proxmox_node.name
  vm_id     = var.vm_id

  agent {
    enabled = true
    timeout = "1m"
  }

  bios    = "ovmf"
  machine = "q35"

  cpu {
    cores = var.proxmox_node.home_assistant.cores
    type  = "host"
  }

  memory {
    dedicated = var.proxmox_node.home_assistant.memory_mb
  }

  efi_disk {
    datastore_id      = "local"
    pre_enrolled_keys = false
    type              = "4m"
  }

  disk {
    datastore_id = "local"
    file_id      = "local:100/vm-100-disk-0.raw"
    interface    = "scsi0"
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  boot_order = ["scsi0"]
  on_boot    = true
}
