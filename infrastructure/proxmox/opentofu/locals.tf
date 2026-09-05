locals {
  # Versions
  kubernetes_version = "v1.34.1"
  talos_version      = "v1.13.9"
  kube_vip_version   = "v1.0.1"

  # Pinned to whatever version the cluster was originally bootstrapped with - this is NOT
  # the fleet's current/target OS version (that's talos_version above) and must never track
  # it. talos_machine_secrets generates the cluster's actual PKI (CA, certs, tokens) once;
  # changing its talos_version regenerates all of it, which would desync every future fresh
  # install's CA from the already-running cluster's. Do not change after initial bootstrap.
  cluster_secrets_talos_version = "v1.11.5"

  # System extensions per role - resolved into installer images via the Talos Image Factory
  # (see cluster.tf's data.http.*_schematic). No per-extension version pinning needed - the
  # Factory resolves compatible extension versions for local.talos_version automatically.
  # Control planes only need qemu-guest-agent; i915 stays universal across workers even
  # though only k8s-livio-w1 has a GPU passed through - see gpu_passthrough_worker_key below.
  #
  # iscsi-tools provides iscsiadm, required by the democratic-csi node driver (#13).
  # On every node - editing this list doesn't apply to running nodes; needs
  # `talosctl upgrade` per node after.
  control_plane_extensions = ["siderolabs/qemu-guest-agent", "siderolabs/iscsi-tools"]
  worker_extensions        = ["siderolabs/i915", "siderolabs/qemu-guest-agent", "siderolabs/iscsi-tools"]

  # GPU passthrough - the livio host's Intel HD 630 iGPU is passed through
  # exclusively to this one worker (a PCI device can only be owned by one VM
  # at a time), so it's used for Jellyfin hardware transcoding.
  gpu_passthrough_worker_key = "livio-w1"
  # Proxmox resource mapping name (see `pvesh get /cluster/mapping/pci` on the livio host),
  # pointing at PCI 0000:00:02.0. Mapped devices can be granted to the terraform API token;
  # raw PCI ids can only be set by root@pam.
  gpu_pci_mapping = "jellyfin-igpu"

  # Network Configuration
  network_subnet = "10.0.10.0/24"
  gateway_ip     = "10.0.10.1"
  cluster_vip    = "10.0.10.2"
  nameservers    = ["9.9.9.9", "1.1.1.1"]

  # VM ID allocation
  control_plane_vm_id_base = 100
  worker_vm_id_base        = 200

  # Control Planes - one per Proxmox host
  control_plane_nodes = {
    for idx, host in var.proxmox_hosts : host.name => {
      proxmox_node   = host.name
      vm_id          = local.control_plane_vm_id_base + idx
      ip_address     = host.control_plane.ip_address
      mac_address    = host.control_plane.mac_address
      hostname       = "k8s-${host.name}-cp"
      cores          = host.control_plane.cores
      memory_mb      = host.control_plane.memory_mb
      template_vm_id = host.template_vm_id
    }
  }

  # Workers - Many per Proxmox host
  worker_nodes = merge([
    for host_idx, host in var.proxmox_hosts :
    { for worker_idx, worker in host.workers :
      "${host.name}-w${worker_idx + 1}" => {
        proxmox_node   = host.name
        vm_id          = local.worker_vm_id_base + (host_idx * 10) + worker_idx + 1
        ip_address     = worker.ip_address
        mac_address    = worker.mac_address
        hostname       = "k8s-${host.name}-w${worker_idx + 1}"
        cores          = worker.cores
        memory_mb      = worker.memory_mb
        template_vm_id = host.template_vm_id
      }
    }
  ]...)

  # Cluster Endpoint - Bootstrap on designated gateway node
  bootstrap_node   = local.control_plane_nodes[var.bootstrap_node_name]
  cluster_endpoint = "https://${local.cluster_vip}:6443"
}
