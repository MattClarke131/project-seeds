# Bootstrapping your Proxmox cluster

1. **[Proxmox Cluster Setup](./proxmox-cluster.md)**
  - Install Proxmox VE on each node
  - Configure networking and static IPs
  - Form the Proxmox cluster

2. **[Tailnet Setup](./tailnet-setup.md)** (optional)
  - Install tailscale on each Proxmox node
  - Connect nodes to the Tailnet

3. **[Network Configuration](./proxmox-network.md)**
  - Create SDN zone and virtual network
  - Configure 10.0.10.0/24 subnet for kubernetes


## Architecture Decisions
See [ADRs](/docs/adr/) for detailed reasoning behind infrastructure choices
