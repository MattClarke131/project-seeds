# Generate Talos machine secrets (certificates, tokens, etc.)
resource "talos_machine_secrets" "this" {}

# Control plane machine configuration
data "talos_machine_configuration" "control_plane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

# Worker machine configuration
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

# Client configuration for talosctl
data "talos_client_configuration" "this" {
  cluster_name  = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints     = [for k, v in local.control_plane_nodes : v.ip_address]
}

# Apply configuration to control plane nodes
resource "talos_machine_configuration_apply" "control_plane" {
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration

  for_each = local.control_plane_nodes
  node     = each.value.ip_address

  config_patches = [
    templatefile("${path.module}/templates/network-config.yaml.tmpl", {
      hostname   = each.key
      ip_address = each.value.ip_address
    })
  ]

  depends_on = [
    proxmox_virtual_environment_vm.talos_control_plane
  ]
}

# Apply configuration to worker nodes
resource "talos_machine_configuration_apply" "worker" {
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration

  for_each = local.worker_nodes
  node     = each.value.ip_address

  config_patches = [
    templatefile("${path.module}/templates/network-config.yaml.tmpl", {
      hostname   = each.key
      ip_address = each.value.ip_address
    })
  ]

  depends_on = [
    proxmox_virtual_environment_vm.talos_worker
  ]
}

# Bootstrap the cluster (only run on first control plane)
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in local.control_plane_nodes : v.ip_address][0]

  depends_on = [
    talos_machine_configuration_apply.control_plane
  ]
}

# Generate kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in local.control_plane_nodes : v.ip_address][0]

  depends_on = [
    talos_machine_bootstrap.this
  ]
}
