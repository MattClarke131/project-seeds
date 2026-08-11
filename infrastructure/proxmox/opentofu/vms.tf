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

# GPU passthrough for k8s-livio-w1 (see locals.gpu_passthrough_worker_key). Applied via
# SSH/qm rather than the provider's native `hostpci` block: the bpg/proxmox provider always
# sends rombar/x-vga alongside mapping, and Proxmox's API rejects that combination for
# non-root tokens ("only root can set 'hostpci0' config for non-mapped devices") even though
# the minimal `mapping=...,pcie=1` form works fine - confirmed this is a Proxmox-side bug,
# not fixable via HCL values. See https://github.com/bpg/terraform-provider-proxmox/issues/495.
resource "null_resource" "gpu_passthrough" {
  for_each = { for k, v in local.worker_nodes : k => v if k == local.gpu_passthrough_worker_key }

  provisioner "local-exec" {
    command = "ssh root@${each.value.proxmox_node} 'qm set ${proxmox_virtual_environment_vm.worker[each.key].vm_id} -hostpci0 mapping=${local.gpu_pci_mapping},pcie=1'"
  }

  # Proxmox's VM id is a fixed, deterministic value (see locals.worker_nodes) that stays the
  # same across a destroy+recreate, so a plain `triggers` map keyed on it or on `.id` would
  # never change and this provisioner would silently skip re-running after a VM replacement.
  # replace_triggered_by ties directly into the VM resource's replace lifecycle instead.
  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.worker[each.key]]
  }

  depends_on = [proxmox_virtual_environment_vm.worker]
}
