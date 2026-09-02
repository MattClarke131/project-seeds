# Talos cluster configuration

# Generate Talos cluster secrets (PKI materials)
resource "talos_machine_secrets" "cluster" {
  talos_version = local.cluster_secrets_talos_version
}

# Resolve each role's extension set into a Talos Image Factory schematic ID, fed into
# machine.install.image below - Talos resolves and pulls this itself at install/upgrade time.
data "http" "control_plane_schematic" {
  url    = "https://factory.talos.dev/schematics"
  method = "POST"
  request_headers = {
    "Content-Type" = "application/json"
  }
  request_body = jsonencode({
    customization = {
      systemExtensions = {
        officialExtensions = local.control_plane_extensions
      }
    }
  })
}

data "http" "worker_schematic" {
  url    = "https://factory.talos.dev/schematics"
  method = "POST"
  request_headers = {
    "Content-Type" = "application/json"
  }
  request_body = jsonencode({
    customization = {
      systemExtensions = {
        officialExtensions = local.worker_extensions
      }
    }
  })
}

locals {
  control_plane_install_image = "factory.talos.dev/installer/${jsondecode(data.http.control_plane_schematic.response_body).id}:${local.talos_version}"
  worker_install_image        = "factory.talos.dev/installer/${jsondecode(data.http.worker_schematic.response_body).id}:${local.talos_version}"
}

# Generate machine configuration for each control plane node
data "talos_machine_configuration" "controlplane" {
  for_each = local.control_plane_nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = local.talos_version
  kubernetes_version = local.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          image = local.control_plane_install_image
        }
        network = {
          hostname = each.value.hostname
          interfaces = [{
            deviceSelector = {
              hardwareAddr = lower(each.value.mac_address)
            }
            addresses = ["${each.value.ip_address}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = local.gateway_ip
            }]
            vip = {
              ip = local.cluster_vip
            }
          }]
          nameservers = local.nameservers
        }
        # Which Proxmox host this VM runs on, for anti-affinity across physical boxes.
        nodeLabels = {
          "topology.${var.cluster_name}/physical-host" = each.value.proxmox_node
        }
      }
      # Talos binds these to 127.0.0.1 by default (loopback-only, unreachable
      # from Prometheus running elsewhere in the cluster). See
      # docs/adr/003-control-plane-metrics-exposure.md for the tradeoff.
      cluster = {
        controllerManager = {
          extraArgs = {
            "bind-address" = "0.0.0.0"
          }
        }
        scheduler = {
          extraArgs = {
            "bind-address" = "0.0.0.0"
          }
        }
        proxy = {
          extraArgs = {
            "metrics-bind-address" = "0.0.0.0:10249"
          }
        }
        etcd = {
          extraArgs = {
            "listen-metrics-urls" = "http://0.0.0.0:2381"
          }
        }
      }
    })
  ]
}

# Talos client configuration for cluster access — rendered on demand via the
# `talosconfig` output (see outputs.tf), not written to disk automatically.
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [local.bootstrap_node.ip_address]
  nodes                = [for node in local.control_plane_nodes : node.ip_address]
}

# Create ISO content for each control plane
resource "local_file" "user_data" {
  for_each = local.control_plane_nodes

  content         = data.talos_machine_configuration.controlplane[each.key].machine_configuration
  filename        = "${path.module}/iso-content/control-plane/${each.key}/user-data"
  file_permission = "0600"
}

resource "local_file" "meta_data" {
  for_each = local.control_plane_nodes

  content = yamlencode({
    instance_id    = each.value.hostname
    local_hostname = each.value.hostname
  })
  filename        = "${path.module}/iso-content/control-plane/${each.key}/meta-data"
  file_permission = "0600"
}

# Generate ISOs for each control plane node
resource "null_resource" "control_plane_iso" {
  for_each = local.control_plane_nodes

  triggers = {
    config_hash = sha256(data.talos_machine_configuration.controlplane[each.key].machine_configuration)
  }

  provisioner "local-exec" {
    command = "mkisofs -o ${path.module}/iso-content/control-plane/${each.key}-cp.iso -V cidata -r -J ${path.module}/iso-content/control-plane/${each.key}"
  }

  depends_on = [local_file.user_data, local_file.meta_data]
}

resource "null_resource" "upload_control_plane_iso" {
  for_each = local.control_plane_nodes

  triggers = {
    iso_hash = null_resource.control_plane_iso[each.key].id
  }

  provisioner "local-exec" {
    command = "scp ${path.module}/iso-content/control-plane/${each.key}-cp.iso root@${each.value.proxmox_node}:/var/lib/vz/template/iso/${each.key}-cp.iso"
  }

  depends_on = [null_resource.control_plane_iso]
}

# Generate machine configuration for each worker node
data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = local.talos_version
  kubernetes_version = local.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          # i915 is universal across workers so any node is upgrade-ready for GPU passthrough
          # without a separate talosctl upgrade later - see locals.gpu_passthrough_worker_key
          # for which node actually has the PCI device attached (hostpci0).
          image = local.worker_install_image
        }
        network = {
          hostname = each.value.hostname
          interfaces = [{
            deviceSelector = {
              hardwareAddr = lower(each.value.mac_address)
            }
            addresses = ["${each.value.ip_address}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = local.gateway_ip
            }]
          }]
          nameservers = local.nameservers
        }
        # Which Proxmox host this VM runs on, for anti-affinity across physical boxes.
        nodeLabels = {
          "topology.${var.cluster_name}/physical-host" = each.value.proxmox_node
        }
      }
    })
  ]
}

# Create ISO content for each worker
resource "local_file" "worker_user_data" {
  for_each = local.worker_nodes

  content         = data.talos_machine_configuration.worker[each.key].machine_configuration
  filename        = "${path.module}/iso-content/worker/${each.key}/user-data"
  file_permission = "0600"
}

resource "local_file" "worker_meta_data" {
  for_each = local.worker_nodes

  content = yamlencode({
    instance_id    = each.value.hostname
    local_hostname = each.value.hostname
  })
  filename        = "${path.module}/iso-content/worker/${each.key}/meta-data"
  file_permission = "0600"
}

# Generate ISOs for each worker node
resource "null_resource" "worker_iso" {
  for_each = local.worker_nodes

  triggers = {
    config_hash = sha256(data.talos_machine_configuration.worker[each.key].machine_configuration)
  }

  provisioner "local-exec" {
    command = "mkisofs -o ${path.module}/iso-content/worker/${each.key}-w.iso -V cidata -r -J ${path.module}/iso-content/worker/${each.key}"
  }

  depends_on = [local_file.worker_user_data, local_file.worker_meta_data]
}

resource "null_resource" "upload_worker_iso" {
  for_each = local.worker_nodes

  triggers = {
    iso_hash = null_resource.worker_iso[each.key].id
  }

  provisioner "local-exec" {
    command = "scp ${path.module}/iso-content/worker/${each.key}-w.iso root@${each.value.proxmox_node}:/var/lib/vz/template/iso/${each.key}-w.iso"
  }

  depends_on = [null_resource.worker_iso]
}
