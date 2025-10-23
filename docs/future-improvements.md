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
