# Future Improvements

## Infrastructure
### TODO
- [ ] Configure https certificates for all services
- [ ] Move off of `:latest` tags for docker images, use specific versions instead. Set up a process for updating these versions regularly.
- [ ] Security audit and hardening
- [ ] Try a transcoding stress test
- [ ] Migrate Bazarr from SQLite to the shared Postgres cluster - it already has native
  postgres support (`postgresql:` block in its config), and its config PVC is on
  `nfs-provisioner`, which is an unreliable storage backend for SQLite's file-locking
  model. Same pattern already used for Radarr/Sonarr.
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
