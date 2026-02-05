locals {
  # Versions
  kubernetes_version = "v1.34.1"
  talos_version = "v1.11.5"
  qemu_guest_agent_version = "10.2.0"
  kube_vip_version = "v1.0.1"

  # Network Configuration
  network_subnet = "10.0.10.0/24"
  gateway_ip     = "10.0.10.1"
  cluster_vip    = "10.0.10.2"
  nameservers    = ["9.9.9.9", "1.1.1.1"]

  # VM ID allocation
  control_plane_vm_id_base = 100
  worker_vm_id_base        = 200

  # Control Planes - one per Proxmox host
  control_plane_nodes = {
    for idx, host in var.proxmox_hosts : host.name => {
      proxmox_node   = host.name
      vm_id          = local.control_plane_vm_id_base + idx
      ip_address     = host.control_plane.ip_address
      hostname       = "k8s-${host.name}-cp"
      cores          = host.control_plane.cores
      memory_mb      = host.control_plane.memory_mb
      template_vm_id = host.template_vm_id
    }
  }

  # Workers - Many per Proxmox host
  worker_nodes = merge([
    for host_idx, host in var.proxmox_hosts :
      { for worker_idx, worker in host.workers:
        "${host.name}-w${worker_idx + 1}" => {
          proxmox_node   = host.name
          vm_id          = local.worker_vm_id_base + (host_idx * 10) + worker_idx + 1
          ip_address     = worker.ip_address
          hostname       = "k8s-${host.name}-w${worker_idx + 1}"
          cores          = worker.cores
          memory_mb      = worker.memory_mb
          template_vm_id = host.template_vm_id
      }
    }
  ]...)

  # Cluster Endpoint - Bootstrap on designated gateway node
  bootstrap_node   = local.control_plane_nodes[var.bootstrap_node_name]
  cluster_endpoint = "https://${local.cluster_vip}:6443"
}
