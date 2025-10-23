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

4. **[Talos Image Setup](./talos.md)**
  - Download and prepare Talos Linux disk image
  - Create Proxmox VM template

5. **[Terraform Configuration](./terraform.md)**
  - Create Proxmox API user and token
  - Configure Terraform variables
  - Deploy Kubernetes cluster VMs

## Architecture Decisions
See [ADRs](/docs/adr/) for detailed reasoning behind infrastructure choices
