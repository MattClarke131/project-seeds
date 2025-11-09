# Generate Talos cluster secrets (PKI materials)
resource "talos_machine_secrets" "cluster" {
  talos_version = local.talos_version
}

# Generate machine configuration for each control plane node
# This will be used to create the user-data and meta-data files for the cloud-init ISO
data "talos_machine_configuration" "control_plane" {
  for_each = local.control_plane_nodes

  cluster_name         = var.cluster_name
  cluster_endpoint     = local.cluster_endpoint
  machine_type         = "controlplane"
  machine_secrets      = talos_machine_secrets.cluster.machine_secrets
  talos_version        = local.talos_version
  kubernetes_version   = local.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        features = {
          hostDNS = {
            enabled = false
          }
        }
        network = {
          hostname   = each.value.hostname
          interfaces = [{
            interface = "eth0"
            addresses = [ "${each.value.ip_address}/24" ]
            routes    = [{
              network = "0.0.0.0/0"
              gateway = local.gateway_ip
            }]
          }]
          nameservers = local.nameservers
        }
      }
    })
  ]
}

# Generate talosconfig for cluster access
data "talos_client_configuration" "this" {

  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [local.bootstrap_node.ip_address]
  nodes                = [for node in local.control_plane_nodes : node.ip_address]
}

resource "local_file" "talosconfig" {
  content        = data.talos_client_configuration.this.talos_config
  filename       = "${path.module}/talosconfig"
  file_permission = "0600"
}

# Create ISO content for each control plane
resource "local_file" "user_data" {
  for_each = local.control_plane_nodes

  content        = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  filename       = "${path.module}/iso-content/control-plane/${each.key}/user-data"
  file_permission = "0600"
}

resource "local_file" "meta_data" {
  for_each = local.control_plane_nodes

  content        = yamlencode({
    instance_id    = each.value.hostname
    local_hostname = each.value.hostname
  })
  filename       = "${path.module}/iso-content/control-plane/${each.key}/meta-data"
  file_permission = "0600"
}

# Generate ISOs for each control plane node
resource "null_resource" "control_plane_iso" {
  for_each = local.control_plane_nodes

  triggers = {
    config_hash = sha256(data.talos_machine_configuration.control_plane[each.key].machine_configuration)
  }

  provisioner "local-exec" {
    command = "mkisofs -o ${path.module}/iso-content/control-plane/${each.key}.iso -V cidata -r -J ${path.module}/iso-content/control-plane/${each.key}"
  }

  depends_on = [
    local_file.user_data,
    local_file.meta_data,
  ]
}

resource "null_resource" "upload_control_plane_iso" {
  for_each = local.control_plane_nodes

  triggers = {
    iso_hash = null_resource.control_plane_iso[each.key].id
  }

  provisioner "local-exec" {
    command = "scp ${path.module}/iso-content/control-plane/${each.key}.iso root@${each.value.proxmox_node}:/var/lib/vz/template/iso/${each.key}-control-plane.iso"
  }

  depends_on = [null_resource.control_plane_iso]
}
