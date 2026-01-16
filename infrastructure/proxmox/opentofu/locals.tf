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
      ip_address     = host.ip_range_base
      hostname       = "k8s-${host.name}-cp"
      cores          = host.cores
      memory_mb      = host.memory_mb / 4
      template_vm_id = host.template_vm_id
    }
  }

  # Workers - Many per Proxmox host
  worker_nodes = merge([
    for idx, host in var.proxmox_hosts :
      merge([
        for worker_idx in [1,2] : {
          "${host.name}-w${worker_idx}" = {
            proxmox_node  = host.name
            vm_id         = local.worker_vm_id_base + (idx * 10) + worker_idx
            ip_address    = cidrhost(local.network_subnet, (idx * 10) + 10 + worker_idx)
            hostname      = "k8s-${host.name}-w${worker_idx}"
            cores         = host.cores
            memory_mb     = host.memory_mb / 4
            template_vm_id = host.template_vm_id
          }
        }
      ]...)
  ]...)

  # Cluster Endpoint - Bootstrap on designated gateway node
  bootstrap_node   = local.control_plane_nodes[var.bootstrap_node_name]
  cluster_endpoint = "https://${local.cluster_vip}:6443"
}
