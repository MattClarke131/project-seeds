locals {
  # Versions
  kubernetes_version = "v1.34.1"
  talos_version = "v1.11.3"
  kube_vip_version = "v1.0.1"

  # Network Configuration
  network_subnet = "10.0.10.0/24"
  gateway_ip     = "10.0.10.1"
  cluster_vip    = "10.0.10.2"
  nameservers    = ["9.9.9.9", "1.1.1.1"]

  # VM ID allocation
  control_plane_vm_id_base = 100

  # Control Planes - one per Proxmox host
  control_plane_nodes = {
    for idx, host_name in sort(keys(var.proxmox_hosts)) : host_name => {
      proxmox_node      = host_name
      vm_id            = local.control_plane_vm_id_base + idx
      ip_address       = var.proxmox_hosts[host_name].ip_range_base
      hostname         = "k8s-cp-${host_name}"
      cores            = var.proxmox_hosts[host_name].cores
      memory_mb        = var.proxmox_hosts[host_name].memory_mb
      template_vm_id   = var.proxmox_hosts[host_name].template_vm_id
    }
  }

  # Cluster Endpoint - Bootstrap on designated gateway node
  bootstrap_node   = local.control_plane_nodes[var.bootstrap_node_name]
  cluster_endpoint = "https://${local.cluster_vip}:6443"
}
