# Future Improvements

## Infrastructure
### TODO
- [ ] Security audit and hardening
- [ ] Try a transcoding stress test
- [ ] Move off of `:latest` tags for docker images, use specific versions instead. Set up a process for updating these versions regularly.
- [ ] Set up Vault by HashiCorp for secrets management
- [ ] Set up cloudflare terraform provider for DNS records, firewall settings, etc.
- [ ] Commit jellyfin config to version control (ConfigMap, init container, helm chart) (low priority)
- [ ] Configure rate limitting and extensive security features on Pangolin
- [ ] End to End TLS encryption
- [ ] Debug and deploy MetalLB for service LoadBalancer IPs *** Important for HA and service accessibility
  - Provides stable VIPs for services (e.g., graphite-exporter at 10.0.10.61)
  - Eliminates single-point-of-failure with NodePort targeting specific node IPs
  - Previous attempt had Layer 2 networking issues - needs investigation
- [ ] Deploy CoreDNS for internal/external DNS resolution
- [ ] Deploy Jellyfin
- [ ] Deploy Velero - Backup/recovery platform
- [ ] Deploy replicated PostgreSQL cluster
- [ ] Implement regular restore testing
- [ ] Abstract dashboard queries - Add custom labels to Prometheus scrape configs, refactor dashboards to use labels instead of hardcoded IPs
  - Have Terraform generate a config file with Helm
  - Terraform should not feed the config directly into Grafana
- [ ] CI/CD Pipeline
  - Update terraform, talos, kubernetes, and docker images automatically
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
- [ ] Migrate VXLAND networking to EVPN/VXLAN
- [ ] Template retention/cleanup automation (keep last N template versions for X days)
- [ ] Ceph cluster for VM disks. (Maybe not)

### Completed
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
