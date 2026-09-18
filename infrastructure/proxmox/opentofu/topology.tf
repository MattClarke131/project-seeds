# Physical/VM topology for the Proxmox fleet
locals {
  # Note: we reserve 4GB for Proxmox itself (host_reserved_mb below)
  proxmox_hosts = [
    {
      name = "nicholas", host_ip = "10.0.10.5", cores = 4, memory_mb = 32768, host_reserved_mb = 4096, template_vm_id = 10000,

      # cp gets priority CPU shares over workers under contention (issue #140), via
      # cpuunits - a normal per-VM QoS field the API token can set.
      control_plane = {
        ip_address   = "10.0.10.30"
        mac_address  = "BC:24:11:5A:34:D5"
        cores        = 4
        memory_mb    = 4096
        datastore_id = "local-zfs"
        disk_size_gb = 50
        cpu_units    = 4096
      }
      workers = [
        {
          ip_address   = "10.0.10.31"
          mac_address  = "BC:24:11:64:EF:4D"
          cores        = 4
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
          cpu_units    = 1024
        },
        {
          ip_address   = "10.0.10.32"
          mac_address  = "BC:24:11:06:3E:03"
          cores        = 4
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
          cpu_units    = 1024
        },
      ]
    },
    {
      name = "livio", host_ip = "10.0.10.10", cores = 4, memory_mb = 32768, host_reserved_mb = 4096, template_vm_id = 20000,

      control_plane = {
        ip_address   = "10.0.10.40"
        mac_address  = "BC:24:11:B2:B0:8C"
        cores        = 4
        memory_mb    = 4096
        datastore_id = "local-zfs"
        disk_size_gb = 50
        cpu_units    = null
      }
      workers = [
        {
          ip_address  = "10.0.10.41"
          mac_address = "BC:24:11:0B:6D:B4"
          cores       = 4
          memory_mb   = 12288
          # Jellyfin's GPU-passthrough transcode workload (see gpu_passthrough_worker_key)
          # needs more local scratch space for /cache than a plain worker - see issue #253.
          datastore_id = "local-zfs"
          disk_size_gb = 100
          cpu_units    = null
        },
        {
          ip_address   = "10.0.10.42"
          mac_address  = "BC:24:11:5B:DE:D9"
          cores        = 4
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
          cpu_units    = null
        },
      ]
    },
    {
      name = "razlo", host_ip = "10.0.10.11", cores = 8, memory_mb = 32768, host_reserved_mb = 4096, template_vm_id = 30000,

      # cp gets priority CPU shares over workers under contention - see nicholas above (issue #140).
      control_plane = {
        ip_address  = "10.0.10.50"
        mac_address = "BC:24:11:86:41:0C"
        cores       = 8
        memory_mb   = 4096
        # Dedicated zpool on its own drive, isolated from worker disk I/O (issue #125).
        datastore_id = "razlo-etcd"
        disk_size_gb = 50
        cpu_units    = 4096
      }
      workers = [
        {
          ip_address   = "10.0.10.51"
          mac_address  = "BC:24:11:07:64:8A"
          cores        = 8
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
          cpu_units    = 1024
        },
        {
          ip_address   = "10.0.10.52"
          mac_address  = "BC:24:11:3E:CF:5B"
          cores        = 8
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
          cpu_units    = 1024
        },
      ]
    }
  ]
}

# Ensures enough memory for proxmox host
resource "terraform_data" "sufficient_memory_validation" {
  lifecycle {
    precondition {
      condition = alltrue([
        for host in local.proxmox_hosts :
        (host.control_plane.memory_mb + sum([for w in host.workers : w.memory_mb]) + host.host_reserved_mb) <= host.memory_mb
      ])
      error_message = "Total VM memory allocation + host_reserved_mb exceeds total host memory on one or more hosts."
    }
  }
}
