# Future Improvements

## Infrastructure
### TODO
- [ ] Security audit and hardening
- [ ] Deploy Velero - Backup/recovery platform
- [ ] Implement regular restore testing
- [ ] Abstract dashboard queries - Add custom labels to Prometheus scrape configs, refactor dashboards to use labels instead of hardcoded IPs
  - Have Terraform generate a config file with Helm
  - Terraform should not feed the config directly into Grafana
- [ ] CI/CD Pipeline
  - Update terraform, talos, kubernetes, and docker images automatically
  - Adopt GitOps (FluxCD or ArgoCD) so committed manifest changes reconcile onto the
    cluster automatically instead of requiring manual `kubectl apply`/`tofu apply`.
- [ ] Tailscale UDP performance optimizations
  ```bash
    root@host:~# tailscale up --advertise-routes=10.0.10.0/24 --accept-routes --ssh --login-server=<login-server>
    Warning: UDP GRO forwarding is suboptimally configured on vmbr0, UDP forwarding throughput capability will increase with a configuration change.
    See https://tailscale.com/s/ethtool-config-udp-gro
  ```
- [ ] Replace SSH password auth with key-based or Vault integration
  - Have different passwords for each node
- [ ] Template retention/cleanup automation (keep last N template versions for X days)

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
- [x] Migrate Bazarr from SQLite to the shared Postgres cluster
- [x] Set up cloudflare terraform provider for DNS records, firewall settings, etc.
