# Future Improvements

## Infrastructure
- [ ] Migrage from Hashicorp/Terraform to OpenSource/Terraform
  - This would be a drop-in replacement
  - Rationale: Avoid licensed software where possible. Use OSS alternatives.
- [ ] CI/CD Pipeline
  - Update terraform, talos, kubernetes, and docker images automatically
- [ ] Proxmox provisioning different hardware profiles
  - One machine currently has more CPU cores than others, and is underprovisioned.
- [ ] Improve talos image distribution
  - Currently, the talos image is downloaded and unpacked on each Proxmox node manually.
  - Automate this step via a script or configuration management tool.
- [ ] Network storage
  - Main data on nfs share.
  - Ceph cluster for VM disks.
- [ ] High availability proxmox_endpoint
  - Currently, the terraform scripts point to a single Proxmox node.
  - Use a load balancer or DNS round-robin to distribute requests across multiple nodes.
- [ ] Tailscale UDP performance optimizations
  ```bash
    root@host:~# tailscale up --advertise-routes=10.0.10.0/24 --accept-routes --ssh --login-server=<login-server>
    Warning: UDP GRO forwarding is suboptimally configured on vmbr0, UDP forwarding throughput capability will increase with a configuration change.
    See https://tailscale.com/s/ethtool-config-udp-gro
  ```
- [ ] Replace SSH password auth with key-based or Vault integration
  - Have different passwords for each node
- [ ] Migrate VXLAND networking to EVPN/VXLAN
- [ ] Have NAT rules on each node instead of a single gateway node
  - [ ] Improves redundancy and load balancing
