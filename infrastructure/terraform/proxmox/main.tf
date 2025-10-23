locals {
  control_plane_base_vmid = 100
  worker_base_vmid        = 200

  control_plane_base_ip   = 10
  worker_base_ip          = 20

  # One control plane node per Proxmox host node
  control_plane_nodes = {
    for i, node in var.proxmox_nodes :
    "k8s-cp-${node.node_name}" => {
      node_name  = node.node_name
      vm_id         = local.control_plane_base_vmid + i
      ip_address = cidrhost("10.0.10.0/24", local.control_plane_base_ip + i)
      template_id = node.template_id
    }
  }

  # Two worker nodes per Proxmox host node
  worker_nodes = merge([
    for i, node in var.proxmox_nodes : {
      "k8s-worker-${node.node_name}-1" = {
        node_name  = node.node_name
        vm_id      = local.worker_base_vmid + i * 2
        ip_address = cidrhost("10.0.10.0/24", local.worker_base_ip + (i * 2))
        template_id = node.template_id
      }
      "k8s-worker-${node.node_name}-2" = {
        node_name  = node.node_name
        vm_id      = local.worker_base_vmid + i * 2 + 1
        ip_address = cidrhost("10.0.10.0/24", local.worker_base_ip + (i * 2) + 1)
        template_id = node.template_id
      }
    }
  ]...)
}

# VMs for Kubernetes Control Plane nodes
resource "proxmox_virtual_environment_vm" "talos_control_plane" {
  for_each = local.control_plane_nodes

  name       = each.key
  node_name  = each.value.node_name
  vm_id      = each.value.vm_id

  clone {
    vm_id     = each.value.template_id
    node_name = each.value.node_name
    full      = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  network_device {
    bridge = "k8sVNet"
  }

  on_boot = true

  operating_system {
    type = "l26"
  }

  migrate = false

  agent {
    enabled = true
    timeout = "1m"
  }
}

# VMs for Kubernetes Worker nodes
resource "proxmox_virtual_environment_vm" "talos_worker" {
  for_each = local.worker_nodes

  name       = each.key
  node_name  = each.value.node_name
  vm_id      = each.value.vm_id

  clone {
    vm_id     = each.value.template_id
    node_name = each.value.node_name
    full      = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  network_device {
    bridge = "k8sVNet"
  }

  on_boot = true

  operating_system {
    type = "l26"
  }

  migrate = false

  agent {
    enabled = true
    timeout = "1m"
  }
}

output "control_plane_vms" {
  value = {
    for k, v in proxmox_virtual_environment_vm.talos_control_plane : k => {
      id         = v.id
      node_name  = v.node_name
      vm_id      = v.vm_id
      ip_address = local.control_plane_nodes[k].ip_address
    }
  }
}

output "worker_vms" {
  value = {
    for k, v in proxmox_virtual_environment_vm.talos_worker : k => {
      id         = v.id
      node_name  = v.node_name
      vm_id      = v.vm_id
      ip_address = local.worker_nodes[k].ip_address
    }
  }
}
