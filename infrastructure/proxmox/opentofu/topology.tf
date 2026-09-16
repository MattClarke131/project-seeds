# Physical/VM topology for the Proxmox fleet
locals {
  # Note: we reserve 4GB for Proxmox itself (host_reserved_mb below)
  proxmox_hosts = [
    {
      name = "nicholas", host_ip = "10.0.10.5", cores = 4, memory_mb = 32768, host_reserved_mb = 4096, template_vm_id = 10000,

      control_plane = {
        ip_address   = "10.0.10.30"
        mac_address  = "BC:24:11:5A:34:D5"
        cores        = 4
        memory_mb    = 4096
        datastore_id = "local-zfs"
        disk_size_gb = 50
      }
      workers = [
        {
          ip_address   = "10.0.10.31"
          mac_address  = "BC:24:11:64:EF:4D"
          cores        = 4
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
        },
        {
          ip_address   = "10.0.10.32"
          mac_address  = "BC:24:11:06:3E:03"
          cores        = 4
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
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
      }
      workers = [
        # w1 runs Jellyfin's GPU-passthrough transcode workload (see gpu_passthrough_worker_key)
        # and needs more local scratch space for /cache than a plain worker - see issue #253.
        {
          ip_address   = "10.0.10.41"
          mac_address  = "BC:24:11:0B:6D:B4"
          cores        = 4
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 100
        },
        {
          ip_address   = "10.0.10.42"
          mac_address  = "BC:24:11:5B:DE:D9"
          cores        = 4
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
        },
      ]
    },
    {
      name = "razlo", host_ip = "10.0.10.11", cores = 8, memory_mb = 32768, host_reserved_mb = 4096, template_vm_id = 30000,

      # Control plane's disk lives on razlo-etcd, a dedicated zpool on its own physical drive,
      # not the shared local-zfs pool workers use - isolates etcd's write latency from
      # contention with worker VM disk I/O (see issue #125).
      control_plane = {
        ip_address   = "10.0.10.50"
        mac_address  = "BC:24:11:86:41:0C"
        cores        = 8
        memory_mb    = 4096
        datastore_id = "razlo-etcd"
        disk_size_gb = 50
      }
      workers = [
        {
          ip_address   = "10.0.10.51"
          mac_address  = "BC:24:11:07:64:8A"
          cores        = 8
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
        },
        {
          ip_address   = "10.0.10.52"
          mac_address  = "BC:24:11:3E:CF:5B"
          cores        = 8
          memory_mb    = 12288
          datastore_id = "local-zfs"
          disk_size_gb = 50
        },
      ]
    }
  ]
}
