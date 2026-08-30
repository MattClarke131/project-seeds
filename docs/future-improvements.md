# Future Improvements

## Infrastructure
### TODO
- [ ] Security audit and hardening
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
- [x] Abstract dashboard queries - custom labels (`host`/`hostname`/`role`) on Prometheus
  scrape configs, dashboards query by label instead of hardcoded IPs. Terraform's
  `prometheus_scrape_targets` output is the source of truth; `sync-prometheus-targets.sh`
  + `apply-prometheus-config.sh` turn it into a committed ConfigMap that Flux applies -
  no direct Terraform-to-Grafana feed. The one remaining manual step (re-running those
  scripts and committing after a node change) isn't automated: this Terraform root has
  no remote backend, so CI can't read `tofu output` without that migrating first. Not
  worth chasing for how rarely nodes change - left as a documented manual step.
- [x] CI/CD Pipeline - image/manifest/provider bumps auto-PR'd via Renovate (docker,
  kubernetes, terraform, and now Talos OS version too - see #106); GitOps rollout
  tracked in #15, hardening in #56. The one remaining piece, OpenTofu apply
  automation (Atlantis or similar), was deliberately declined for now: not worth
  the remote-state-backend migration and credential relocation it'd require, given
  how infrequently this Terraform root actually changes. No ticket filed - revisit
  if that calculus changes.
