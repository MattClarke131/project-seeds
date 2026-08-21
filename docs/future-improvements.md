# Future Improvements

## Infrastructure
### TODO
- [ ] Upgrade RAM on `livio` (4x8GB -> 4x16GB, ~$140-160) *** Urgent
  - Host is at 1.4GB free (29GB/31GB used) - tightest of the three Proxmox hosts,
    and the only one carrying `k8s-livio-w1` (the Jellyfin GPU transcode worker).
    Intel iGPU transcoding draws frame buffer memory from system RAM, not
    dedicated VRAM, so concurrent/4K/HDR streams add bursty pressure on top of
    an already-thin margin. A host-level OOM here kills the VM outright (not
    graceful), taking down whatever's scheduled on it mid-stream.
  - `nicholas` and `livio` are 4x8GB (all 4 DIMM slots full, needs a full swap
    to grow). `razlo` is 2x16GB with 2 free slots (cheap fill, ~$70-80,
    lower priority since it's not memory-constrained today).
- [ ] Set up Prometheus alerting rules across the board (node memory/CPU pressure,
  OOMKilled events, pod restarts, PVC usage, cert expiry, etc.) - currently have
  Prometheus/Grafana deployed for dashboards but no alerting configured, so
  problems (e.g. `livio`'s tight memory margin) are only found by manually
  checking rather than being surfaced proactively.
- [ ] Configure https certificates for all services
- [ ] Move off of `:latest` tags for docker images, use specific versions instead. Set up a process for updating these versions regularly.
- [ ] Security audit and hardening
- [ ] Try a transcoding stress test
- [ ] Migrate Bazarr from SQLite to the shared Postgres cluster - it already has native
  postgres support (`postgresql:` block in its config), and its config PVC is on
  `nfs-provisioner`, which is an unreliable storage backend for SQLite's file-locking
  model. Same pattern already used for Radarr/Sonarr.
- [ ] Move off `nfs-subdir-external-provisioner` (non-CSI) to a CSI-based NFS driver
  (e.g. `csi-driver-nfs`) or real block storage (e.g. iSCSI off the TrueNAS host,
  or Longhorn). `nfs-subdir-external-provisioner` doesn't enforce ReadWriteOnce
  exclusivity, so a RollingUpdate can briefly double-mount a single-replica app's
  config PVC across two nodes and corrupt whatever's on it - this already happened
  to Bazarr's SQLite db. Every `downloads-standard` deployment is on `strategy:
  Recreate` now as a workaround (safe, but costs a few seconds of downtime per
  deploy). A CSI driver supporting `ReadWriteOncePod` would let Kubernetes itself
  refuse the double-mount and let RollingUpdate come back safely.
  Not urgent yet, but worth resolving soon rather than continuing to paper over it.
- [ ] Set up Vault by HashiCorp for secrets management
- [ ] Set up cloudflare terraform provider for DNS records, firewall settings, etc.
- [ ] Consider a Terraform-managed router/DHCP server. Would keep IP assignment in git
  alongside everything else, and sidestep interface-naming fragility (like what broke
  `nicholas-cp`) since nodes would no longer need to self-identify a specific NIC.
- [ ] Next time a Proxmox VM template is rebuilt, go fully generic (no baked-in extensions)
  now that `cluster.tf` resolves them via `install.image`/Image Factory - avoids redundant
  reinstall-on-first-boot. Needs `wait_for_ip` in `vms.tf`'s `agent` block addressed first
  (currently relies on the template's baked-in `qemu-guest-agent` to satisfy it quickly;
  we already know every node's static IP so waiting on the agent isn't actually needed).
  Also update `docs/bootstrap/talos.md` at the same time - it still describes extensions as
  needing to be baked into the template, which is outdated now that `cluster.tf` resolves
  them via `install.image` instead of the deprecated `install.extensions`.
- [ ] Commit jellyfin config to version control (ConfigMap, init container, helm chart) (low priority)
- [ ] Configure rate limitting and extensive security features on Pangolin
- [ ] End to End TLS encryption
- [ ] Debug and deploy MetalLB for service LoadBalancer IPs *** Important for HA and service accessibility
  - Provides stable VIPs for services (e.g., graphite-exporter at 10.0.10.61)
  - Eliminates single-point-of-failure with NodePort targeting specific node IPs
  - Previous attempt had Layer 2 networking issues - needs investigation
- [ ] Deploy CoreDNS for internal/external DNS resolution
- [ ] Deploy Velero - Backup/recovery platform
- [ ] Implement regular restore testing
- [ ] Abstract dashboard queries - Add custom labels to Prometheus scrape configs, refactor dashboards to use labels instead of hardcoded IPs
  - Have Terraform generate a config file with Helm
  - Terraform should not feed the config directly into Grafana
- [ ] CI/CD Pipeline
  - Update terraform, talos, kubernetes, and docker images automatically
  - Adopt GitOps (FluxCD or ArgoCD) so committed manifest changes reconcile onto the
    cluster automatically instead of requiring manual `kubectl apply`/`tofu apply`.
- [ ] Improve talos image distribution
  - Currently, the talos image is downloaded and unpacked on each Proxmox node manually.
  - Automate this step via a script or configuration management tool.
- [ ] Tailscale UDP performance optimizations
  ```bash
    root@host:~# tailscale up --advertise-routes=10.0.10.0/24 --accept-routes --ssh --login-server=<login-server>
    Warning: UDP GRO forwarding is suboptimally configured on vmbr0, UDP forwarding throughput capability will increase with a configuration change.
    See https://tailscale.com/s/ethtool-config-udp-gro
  ```
- [ ] Replace SSH password auth with key-based or Vault integration
  - Have different passwords for each node
- [ ] Template retention/cleanup automation (keep last N template versions for X days)
- [ ] Ceph cluster for VM disks. (Maybe not)

### Completed
- [x] Deploy Jellyfin
- [x] Deploy replicated PostgreSQL cluster
- [x] Increase postgres instances to 2+, and ensure they're distributed across physical hosts
- [x] Deploy Loki for centralized logging
- [x] Explicitly set resource allocation for each VM
- [x] Migrage from Hashicorp/Terraform to OpenTofu
  - This would be a drop-in replacement
  - Rationale: Avoid licensed software where possible. Use OSS alternatives.
- [x] Proxmox provisioning different hardware profiles
  - One machine currently has more CPU cores than others, and is underprovisioned.
- [x] Network storage
  - Main data on nfs share.
- [x] High availability proxmox_endpoint
  - Currently, the terraform scripts point to a single Proxmox node.
  - Use a load balancer or DNS round-robin to distribute requests across multiple nodes.
- [x] Have NAT rules on each node instead of a single gateway node
  - [x] Improves redundancy and load balancing
- [x] Deploy Prometheus and Grafana for monitoring
