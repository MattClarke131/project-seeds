# Physical/VM topology for the Proxmox fleet
locals {
  # Note: we reserve 4GB for Proxmox itself (host_reserved_mb below)
  proxmox_hosts = [
    {
      name = "nicholas", host_ip = "10.0.10.5", cores = 4, memory_mb = 32768, host_reserved_mb = 4096, template_vm_id = 10000,

      # cp is pinned to a dedicated thread to prevent worker CPU steal (issue #140); nicholas has
      # no hyperthreading, so unlike razlo below, one thread is already a whole physical core.
      control_plane = {
        ip_address   = "10.0.10.30"
        mac_address  = "BC:24:11:5A:34:D5"
        cores        = 4
        memory_mb    = 4096
        datastore_id = "local-zfs"
        disk_size_gb = 50
        affinity     = "0"
      }
      workers = [
        {
          ip_address   = "10.0.10.31"
          mac_address  = "BC:24:11:64:EF:4D"
          cores        = 4
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
          affinity     = "1,2,3"
        },
        {
          ip_address   = "10.0.10.32"
          mac_address  = "BC:24:11:06:3E:03"
          cores        = 4
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
          affinity     = "1,2,3"
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
        affinity     = null
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
          affinity     = null
        },
        {
          ip_address   = "10.0.10.42"
          mac_address  = "BC:24:11:5B:DE:D9"
          cores        = 4
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
          affinity     = null
        },
      ]
    },
    {
      name = "razlo", host_ip = "10.0.10.11", cores = 8, memory_mb = 32768, host_reserved_mb = 4096, template_vm_id = 30000,

      # Control plane's disk lives on razlo-etcd, a dedicated zpool on its own physical drive,
      # not the shared local-zfs pool workers use - isolates etcd's write latency from
      # contention with worker VM disk I/O (see issue #125).
      #
      # cp is also pinned to a dedicated physical core (both HT siblings - a lone thread
      # isn't real isolation since siblings share execution resources) to prevent worker
      # CPU steal from etcd/apiserver (issue #140).
      control_plane = {
        ip_address   = "10.0.10.50"
        mac_address  = "BC:24:11:86:41:0C"
        cores        = 8
        memory_mb    = 4096
        datastore_id = "razlo-etcd"
        disk_size_gb = 50
        affinity     = "0,4"
      }
      workers = [
        {
          ip_address   = "10.0.10.51"
          mac_address  = "BC:24:11:07:64:8A"
          cores        = 8
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
          affinity     = "1,2,3,5,6,7"
        },
        {
          ip_address   = "10.0.10.52"
          mac_address  = "BC:24:11:3E:CF:5B"
          cores        = 8
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
          affinity     = "1,2,3,5,6,7"
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
