# Proxmox Kubernetes Cluster

OpenTofu configuration for provisioning Talos Linux VMs on Proxmox cluster.

## Provisioning

Deploy the cluster VMs:
```bash
tofu init
tofu apply
```

## Bootstrap Cluster

Initialize Kubernetes and generate kubeconfig:
```bash
# Bootstrap etcd and control plane
talosctl bootstrap --nodes 10.0.10.30 --talosconfig ./talosconfig

# Generate kubeconfig for kubectl access
talosctl kubeconfig --nodes 10.0.10.30 --talosconfig ./talosconfig --force

# Verify cluster
kubectl get nodes
```
