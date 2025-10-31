# Generate Talos machine secrets (certificates, tokens, etc.)
resource "talos_machine_secrets" "this" {}

# Control plane machine configuration
# (One per node with network config)
data "talos_machine_configuration" "control_plane" {
  for_each = local.control_plane_nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.key
          interfaces = [{
            interface = "eth0"
            addresses = ["${each.value.ip_address}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = "10.0.10.1"
            }]
          }]
        }
      }
    })
  ]
}

# Worker machine configuration
# (One per node with network config)
data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.key
          interfaces = [{
            interface = "eth0"
            addresses = ["${each.value.ip_address}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = "10.0.10.1"
            }]
          }]
        }
      }
    })
  ]
}

# Client configuration for talosctl
data "talos_client_configuration" "this" {
  cluster_name  = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints     = [for k, v in local.control_plane_nodes : v.ip_address]
}

# Write control plane configs to local files
resource "local_file" "controlplane_config" {
  for_each = local.control_plane_nodes
  content  = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  filename = "${path.module}/generated/controlplane-${each.key}.yaml"
}

# Write worker configs to local files
resource "local_file" "worker_config" {
  for_each = local.worker_nodes
  content  = data.talos_machine_configuration.worker[each.key].machine_configuration
  filename = "${path.module}/generated/worker-${each.key}.yaml"
}

# Upload control plane configs as Proxmox snippets
resource "proxmox_virtual_environment_file" "controlplane_config" {
  for_each = local.control_plane_nodes

  content_type = "snippets"
  datastore_id = "local"
  node_name    = each.value.node_name

  source_raw {
    data      = local_file.controlplane_config[each.key].content
    file_name = "controlplane-${each.key}.yaml"
  }

  depends_on = [local_file.controlplane_config]
}

# Upload worker configs as Proxmox snippets
resource "proxmox_virtual_environment_file" "worker_config" {
  for_each = local.worker_nodes

  content_type = "snippets"
  datastore_id = "local"
  node_name    = each.value.node_name

  source_raw {
    data      = local_file.worker_config[each.key].content
    file_name = "worker-${each.key}.yaml"
  }

  depends_on = [local_file.worker_config]
}
