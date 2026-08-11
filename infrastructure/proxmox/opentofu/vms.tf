# Create control plane VMs
resource "proxmox_virtual_environment_vm" "control_plane" {
  for_each = local.control_plane_nodes

  name        = each.value.hostname
  description = "Talos Control Plane Node"
  node_name   = each.value.proxmox_node
  vm_id       = each.value.vm_id

  agent {
    enabled = true
  }

  clone {
    vm_id = each.value.template_vm_id
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  network_device {
    bridge      = var.proxmox_bridge
    model       = "virtio"
    mac_address = each.value.mac_address
  }

  cdrom {
    file_id   = "local:iso/${each.key}-cp.iso"
  }

  depends_on = [null_resource.upload_control_plane_iso]

  on_boot = true
}

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = local.worker_nodes

  name        = each.value.hostname
  description = "Talos Worker Node"
  node_name   = each.value.proxmox_node
  vm_id       = each.value.vm_id

  agent {
    enabled = true
  }

  clone {
    vm_id = each.value.template_vm_id
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  network_device {
    bridge      = var.proxmox_bridge
    model       = "virtio"
    mac_address = each.value.mac_address
  }

  cdrom {
    file_id   = "local:iso/${each.key}-w.iso"
  }

  depends_on = [null_resource.upload_worker_iso]

  on_boot = true
}
