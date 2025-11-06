locals {
  kubernetes_version = "v1.34.1"
  talos_version = "v1.11.3"

  # VM Specifications
  vm_cpu_cores  = 4
  vm_memory_mb  = 4096
  vm_disk_size  = "50G"

  # Single control plane for Step 1
  control_plane = {
    node_name      = "nicholas"
    vm_id          = 100
    ip_address     = "10.0.10.10"
    template_vm_id = 9000
  }

  # Network Configuration
  gateway_ip = "10.0.10.1"
  nameservers = ["9.9.9.9", "1.1.1.1"]
}

data "talos_machine_configuration" "control" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${local.control_plane.ip_address}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = local.talos_version

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname   = "k8s-cp-${local.control_plane.node_name}"
          interfaces = [{
            interface = "eth0"
            addresses = [ "${local.control_plane.ip_address}/24" ]
            routes    = [
              {
                network = "0.0.0.0/0"
                gateway = local.gateway_ip
              }
            ]
          }]
          nameservers = local.nameservers
        }
      }
    })
  ]
}

resource "talos_machine_secrets" "cluster" {
  talos_version = local.talos_version
}

resource "local_file" "user_data" {
  content  = data.talos_machine_configuration.control.machine_configuration
  filename = "${path.module}/iso-content/control-plane/user-data"
  file_permission = "0600"
}

resource "local_file" "meta_data" {
  content  = yamlencode({
    instance_id    = "k8s-cp-${local.control_plane.node_name}"
    local_hostname = "k8s-cp-${local.control_plane.node_name}"
  })
  filename = "${path.module}/iso-content/control-plane/meta-data"
  file_permission = "0600"
}

resource "null_resource" "control_plane_iso" {
  triggers = {
    config_hash = sha256(data.talos_machine_configuration.control.machine_configuration)
  }

  provisioner "local-exec" {
    command = "mkisofs -o ${path.module}/iso-content/control-plane.iso -V cidata -r -J ${path.module}/iso-content/control-plane"
  }

  depends_on = [
    local_file.user_data,
    local_file.meta_data,
  ]
}

resource "null_resource" "upload_control_plane_iso" {
  triggers = {
    iso_hash = null_resource.control_plane_iso.id
  }

  provisioner "local-exec" {
    command = "scp ${path.module}/iso-content/control-plane.iso root@${local.control_plane.node_name}:/var/lib/vz/template/iso/"
  }

  depends_on = [null_resource.control_plane_iso]
}

resource "proxmox_virtual_environment_vm" "control_plane" {
  name        = "k8s-cp-${local.control_plane.node_name}"
  description = "Talos Control Plane Node"
  node_name   = local.control_plane.node_name
  vm_id       = local.control_plane.vm_id

  clone {
    vm_id = local.control_plane.template_vm_id
  }

  cpu {
    cores = local.vm_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = local.vm_memory_mb
  }

  network_device {
    bridge = var.proxmox_bridge
    model  = "virtio"
  }

  cdrom {
    file_id   = "local:iso/control-plane.iso"
  }

  depends_on = [null_resource.upload_control_plane_iso]

  on_boot = true
}

# # Generate Talos cluster secrets
# resource "talos_machine_secrets" "cluster" {
#   talos_version = local.talos_version
# }

# # Data source for Talos image
# data "talos_image_factory_urls" "this" {
#   talos_version = local.talos_version
#   platform      = "nocloud"
#   architecture  = "amd64"
#   schematic_id = "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
# }

# # Generate control plane machine configurations
# data "talos_machine_configuration" "control_plane" {
#   for_each = local.control_planes

#   cluster_name       = var.cluster_name
#   cluster_endpoint   = local.cluster_endpoint
#   machine_type       = "controlplane"
#   machine_secrets    = talos_machine_secrets.cluster.machine_secrets
#   talos_version      = local.talos_version
#   kubernetes_version = local.kubernetes_version

#   config_patches = [
#     yamlencode({
#       machine = {
#         network = {
#           hostname   = each.value.hostname
#           interfaces = [{
#             interface = "eth0"
#             addresses = [ "${each.value.ip_address}/${local.network_cidr}" ]
#             routes    = [
#               {
#                 network = "0.0.0.0/0"
#                 gateway = var.network_gateway
#               }
#             ]
#           }]
#         }
#       }
#     })
#   ]
# }

# # Generate worker machine configurations
# data "talos_machine_configuration" "worker" {
#   for_each = local.workers

#   cluster_name       = var.cluster_name
#   cluster_endpoint   = local.cluster_endpoint
#   machine_type       = "worker"
#   machine_secrets    = talos_machine_secrets.cluster.machine_secrets
#   talos_version      = local.talos_version
#   kubernetes_version = local.kubernetes_version

#   config_patches = [
#     yamlencode({
#       machine = {
#         network = {
#           hostname   = each.value.hostname
#           interfaces = [{
#             interface = "eth0"
#             addresses = [ "${each.value.ip_address}/${local.network_cidr}" ]
#             routes    = [
#               {
#                 network = "0.0.0.0/0"
#                 gateway = var.network_gateway
#               }
#             ]
#           }]
#         }
#       }
#     })
#   ]
# }

# # Generate talosconfig
# data "talos_client_configuration" "this" {
#   cluster_name         = var.cluster_name
#   client_configuration = talos_machine_secrets.cluster.client_configuration
#   endpoints            = [local.bootstrap_node.ip_address]
#   nodes                = [local.bootstrap_node.ip_address]
# }

# # Local configuration
# locals {
#   # Hardcoded versions
#   talos_version = "v1.11.3"
#   kubernetes_version = "v1.34.1"

#   # Template base
#   template_vm_id_base = 9000 

#   # VM specs
#   vm_memory = 4096
#   vm_cores  = 4
#   vm_disk_size = "50G"
#   vm_storage = "local-zfs"

#   # Network configuration
#   dns_servers = ["9.9.9.9", "8.8.8.8", "1.1.1.1"]
#   network_cidr = 24

#   # IP allocation
#   control_plane_base_id   = 10
#   worker_base_id          = 20
#   control_plane_vm_id_base = 100
#   worker_vm_id_base        = 200

#   # Control Plane
#   control_plane_node_list = flatten([
#     for host_name, host_config in var.proxmox_hosts : [
#       for i in range(host_config.control_planes) : {
#         key          = "${host_name}-cp"
#         proxmox_node = host_name
#         index        = i
#       }
#     ]
#   ])

#   control_planes = {
#     for idx, cp in local.control_plane_node_list : cp.key => {
#       ip_address   = "${var.network_base_ip}.${local.control_plane_base_id + idx}"
#       proxmox_node = cp.proxmox_node
#       hostname     = "k8s-cp-${cp.proxmox_node}"
#       vm_id       = local.control_plane_vm_id_base + idx
#     }
#   }

#   # Workers
#   worker_node_list = flatten([
#     for host_name, host_config in var.proxmox_hosts : [
#       for i in range(host_config.workers) : {
#         key          = "${host_name}-worker-${i + 1}"
#         proxmox_node = host_name
#         index        = i
#       }
#     ]
#   ])

#   workers = {
#     for idx, worker in local.worker_node_list : worker.key => {
#       ip_address   = "${var.network_base_ip}.${local.worker_base_id + idx}"
#       proxmox_node = worker.proxmox_node
#       hostname     = "k8s-worker-${worker.proxmox_node}-${worker.index + 1}"
#       vm_id       = local.worker_vm_id_base + idx
#     }
#   }

#   # Cluster configuration
#   first_control_plane = sort(keys(local.control_planes))[0]
#   bootstrap_node      = local.control_planes[local.first_control_plane]
#   cluster_endpoint    = "https://${local.bootstrap_node.ip_address}:6443"
# }

# # Create ISO content directories and files for control plane nodes
# resource "local_file" "control_plane_user_data" {
#   for_each = local.control_planes

#   filename = "${path.module}/iso-content/${each.key}/user-data"
#   content  = data.talos_machine_configuration.control_plane[each.key].machine_configuration
# }

# resource "local_file" "control_plane_meta_data" {
#   for_each = local.control_planes

#   filename = "${path.module}/iso-content/${each.key}/meta-data"
#   content  = yamlencode({ instance_id = each.value.hostname })
# }

# # Create ISOs for control planes
# resource "null_resource" "control_plane_iso" {
#   for_each = local.control_planes

#   depends_on = [
#     local_file.control_plane_user_data,
#     local_file.control_plane_meta_data,
#   ]

#   triggers = {
#     config_hash = sha256(data.talos_machine_configuration.control_plane[each.key].machine_configuration)
#   }

#   provisioner "local-exec" {
#     command = "mkisofs -o ${path.module}/iso-content/${each.key}.iso -V cidata -r -J ${path.module}/iso-content/${each.key}"
#   }
# }

# # Create ISO content directories and files for worker nodes
# resource "local_file" "worker_user_data" {
#   for_each = local.workers

#   filename = "${path.module}/iso-content/${each.key}/user-data"
#   content  = data.talos_machine_configuration.worker[each.key].machine_configuration
# }

# # Create ISOs for workers
# resource "local_file" "worker_meta_data" {
#   for_each = local.workers

#   filename = "${path.module}/iso-content/${each.key}/meta-data"
#   content  = yamlencode({ instance_id = each.value.hostname })
# }

# # Create ISOs for workers
# resource "null_resource" "worker_iso" {
#   for_each = local.workers

#   depends_on = [
#     local_file.worker_user_data,
#     local_file.worker_meta_data,
#   ]

#   triggers = {
#     config_hash = sha256(data.talos_machine_configuration.worker[each.key].machine_configuration)
#   }

#   provisioner "local-exec" {
#     command = "mkisofs -o ${path.module}/iso-content/${each.key}.iso -V cidata -r -J ${path.module}/iso-content/${each.key}"
#   }
# }

# # Upload control plane ISOs to Proxmox nodes
# resource "null_resource" "upload_control_plane_iso" {
#   for_each = local.control_planes

#   depends_on = [
#     null_resource.control_plane_iso,
#   ]

#   triggers = {
#     config_hash = sha256(data.talos_machine_configuration.control_plane[each.key].machine_configuration)
#   }

#   connection {
#     type  = "ssh"
#     host  = each.value.proxmox_node
#     user  = "root"
#     agent = true
#   }

#   provisioner "file" {
#     source      = "${path.module}/iso-content/${each.key}.iso"
#     destination = "/var/lib/vz/template/iso/${each.key}-config.iso"
#   }
# }

# # Upload worker ISOs to Proxmox nodes
# resource "null_resource" "upload_worker_iso" {
#   for_each = local.workers

#   depends_on = [
#     null_resource.worker_iso
#   ]

#   triggers = {
#     config_hash = sha256(data.talos_machine_configuration.worker[each.key].machine_configuration)
#   }

#   connection {
#     type  = "ssh"
#     host  = each.value.proxmox_node
#     user  = "root"
#     agent = true
#   }

#   provisioner "file" {
#     source      = "${path.module}/iso-content/${each.key}.iso"
#     destination = "/var/lib/vz/template/iso/${each.key}-config.iso"
#   }
# }

# # Download and create template on each Proxmox node
# resource "null_resource" "talos_template" {
#   for_each = var.proxmox_hosts

#   triggers = {
#     talos_version = local.talos_version
#     image_url     = data.talos_image_factory_urls.this.urls.disk_image
#     node_name     = each.key
#   }

#   connection {
#     type        = "ssh"
#     host        = each.key
#     user        = "root"
#     agent       = true
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "set -e",
#       "TEMPLATE_ID=${each.value.template_vm_id}",

#       "# Check if template exists with correct version",
#       "if qm config $TEMPLATE_ID 2>/dev/null | grep -q '^name: talos-${local.talos_version}-template$'; then",
#       "  echo 'template already exists with correct version on node ${each.key}, skipping creation'",
#       "  exit 0",
#       "fi",

#       "echo 'Creating or updating template on ${each.key}'",
#       "cd /var/lib/vz/template/iso",

#       "# Remove existing nocloud image files if any",
#       "rm -f nocloud-amd64.raw nocloud-amd64.raw.xz",

#       "# Download Talos nocloud image",
#       "wget '${data.talos_image_factory_urls.this.urls.disk_image}' -O nocloud-amd64.raw.xz",
#       "xz -d nocloud-amd64.raw.xz",

#       "# Destroy existing template if exists",
#       "qm destroy $TEMPLATE_ID 2>/dev/null || true",

#       "# Create Proxmox template from Talos nocloud image",
#       "qm create $TEMPLATE_ID --name talos-${local.talos_version}-template --memory ${local.vm_memory} --cores ${local.vm_cores} --net0 virtio,bridge=${var.proxmox_bridge} --scsihw virtio-scsi-pci --cpu host",
#       "qm importdisk $TEMPLATE_ID /var/lib/vz/template/iso/nocloud-amd64.raw ${local.vm_storage}",
#       "qm set $TEMPLATE_ID --scsi0 ${local.vm_storage}:vm-$${TEMPLATE_ID}-disk-0 --boot order=scsi0 --serial0 socket",
#       "qm resize $TEMPLATE_ID scsi0 ${local.vm_disk_size}",

#       "# Convert to template",
#       "qm template $TEMPLATE_ID",

#       "echo 'Talos template created on node ${each.key}'"
#     ]
#   }
# }

# # Create control plane VMs
# resource "proxmox_virtual_environment_vm" "control_plane" {
#   for_each = local.control_planes

#   depends_on = [
#     null_resource.talos_template,
#     null_resource.upload_control_plane_iso,
#   ]

#   name      = each.value.hostname
#   node_name = each.value.proxmox_node
#   vm_id      = each.value.vm_id

#   clone {
#     vm_id = var.proxmox_hosts[each.value.proxmox_node].template_vm_id
#   }

#   cpu {
#     cores = local.vm_cores
#     type  = "host"
#   }

#   memory {
#     dedicated = local.vm_memory
#   }

#   network_device {
#     bridge = var.proxmox_bridge
#     model  = "virtio"
#   }

#   cdrom {
#     file_id   = "local:iso/${each.key}-config.iso"
#     interface = "ide2"
#   }

#   serial_device {}

#   started = true
# }

# # Create worker VMs
# resource "proxmox_virtual_environment_vm" "worker" {
#   for_each = local.workers

#   depends_on = [
#     null_resource.talos_template,
#     null_resource.upload_worker_iso,
#   ]

#   name      = each.value.hostname
#   node_name = each.value.proxmox_node
#   vm_id      = each.value.vm_id

#   clone {
#     vm_id = var.proxmox_hosts[each.value.proxmox_node].template_vm_id
#   }

#   cpu {
#     cores = local.vm_cores
#     type  = "host"
#   }

#   memory {
#     dedicated = local.vm_memory
#   }

#   network_device {
#     bridge = var.proxmox_bridge
#     model  = "virtio"
#   }

#   cdrom {
#     file_id   = "local:iso/${each.key}-config.iso"
#     interface = "ide2"
#   }

#   serial_device {}

#   started = true
# }

# resource "null_resource" "talos_bootstrap" {
#   depends_on = [
#     proxmox_virtual_environment_vm.control_plane,
#     local_file.talosconfig
#   ]

#   provisioner "local-exec" {
#     command = <<-EOT
#     talosctl bootstrap --nodes ${local.bootstrap_node.ip_address} --endpoints ${local.bootstrap_node.ip_address} --talosconfig ${path.module}/talosconfig
#     EOT
#   }

#   provisioner "local-exec" {
#     command = <<-EOT
#       talosctl health --nodes ${local.bootstrap_node.ip_address} --endpoints ${local.bootstrap_node.ip_address} --talosconfig ${path.module}/talosconfig --wait-timeout 10m
#     EOT
#   }
# }

# # Join additional control planes
# resource "null_resource" "talos_join_control_plane" {
#   for_each = { for k, v in local.control_planes : k => v if k != local.first_control_plane }

#   depends_on = [null_resource.talos_bootstrap]

#   provisioner "local-exec" {
#     command = <<-EOT
#       talosctl apply-config \
#         --nodes ${each.value.ip_address} \
#         --endpoints ${each.value.ip_address} \
#         --talosconfig ${path.module}/talosconfig \
#         --file <(echo '${data.talos_machine_configuration.control_plane[each.key].machine_configuration}')
#     EOT
#     interpreter = ["bash", "-c"]
#   }
# }

# # Join workers
# resource "null_resource" "talos_join_worker" {
#   for_each = local.workers

#   depends_on = [null_resource.talos_bootstrap]

#   provisioner "local-exec" {
#     command = <<-EOT
#       talosctl apply-config \
#         --nodes ${each.value.ip_address} \
#         --endpoints ${each.value.ip_address} \
#         --talosconfig ${path.module}/talosconfig \
#         --file <(echo '${data.talos_machine_configuration.worker[each.key].machine_configuration}')
#     EOT
#     interpreter = ["bash", "-c"]
#   }
# }

# resource "local_file" "talosconfig" {
#   filename        = "${path.module}/talosconfig"
#   content         = data.talos_client_configuration.this.talos_config
#   file_permission = "0600"
# }

# # Outputs
# output "talos_config" {
#   description = "Talos configuration for cluster access"
#   value       = talos_machine_secrets.cluster.client_configuration
#   sensitive   = true
# }

# output "cluster_endpoint" {
#   description = "Kubernetes API server endpoint"
#   value       = local.cluster_endpoint
# }

# output "bootstrap_node" {
#   description = "Bootstrap control plane node details"
#   value       = {
#     keyname     = local.first_control_plane
#     hostname    = local.bootstrap_node.hostname
#     ip_address  = local.bootstrap_node.ip_address
#     proxmox_node = local.bootstrap_node.proxmox_node
#   }
# }

# output "control_planes" {
#   description = "All control plane nodes"
#   value       = local.control_planes
# }

# output "workers" {
#   description = "All worker nodes"
#   value       = local.workers
# }
