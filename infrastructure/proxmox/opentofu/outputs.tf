# Talos config file location
output "talosconfig_path" {
  description = "Path to the Talos config file"
  value       = abspath("${path.module}/talosconfig")
}

# Cluster endpoint
output "cluster_endpoint" {
  description = "Kubernetes cluster API endpoint"
  value       = local.cluster_endpoint
}

# Bootstrap node details
output "bootstrap_node" {
  description = "Bootstrap control plane node"
  value = {
    name       = var.bootstrap_node_name
    hostname   = local.bootstrap_node.hostname
    ip_address = local.bootstrap_node.ip_address
    vm_id      = local.bootstrap_node.vm_id
  }
}

# All control plane nodes
output "control_plane_nodes" {
  description = "All control plane nodes"
  value = {
    for key, node in local.control_plane_nodes : key => {
      hostname     = node.hostname
      ip_address   = node.ip_address
      vm_id        = node.vm_id
      proxmox_node = node.proxmox_node
    }
  }
}

# Variables for Prometheus scrape targets
output "prometheus_scrape_targets" {
  description = "Prometheus scrape targets in file_sd format"
  value = flatten([
    for host in var.proxmox_hosts : [
      {
        targets = ["${host.host_ip}:9100"]
        labels = {
          host     = host.name
          hostname = "${host.name}-host"
          role     = "host"
        }
      },
      {
        targets = ["${local.control_plane_nodes[host.name].ip_address}:9100"]
        labels = {
          host     = host.name
          hostname = local.control_plane_nodes[host.name].hostname
          role     = "control_plane"
        }
      },
      [
        for worker_name, worker in local.worker_nodes :
        {
          targets = ["${worker.ip_address}:9100"]
          labels = {
            host     = host.name
            hostname = worker.hostname
            role     = "worker"
          }
        }
        if worker.proxmox_node == host.name
      ]
    ]
  ])
}
