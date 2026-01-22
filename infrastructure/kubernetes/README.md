# Kubernetes Workloads

Kubernetes workload configurations for the homelab cluster. See subdirectories for component-specific deployments and documentation.

## Prerequisites

Requires a running Talos Kubernetes cluster. See [../proxmox/opentofu/](../proxmox/opentofu/) for cluster provisioning.

## Quick Commands
```bash
# Apply storage configuration
kubectl apply -f storage/

# Verify cluster status
kubectl get nodes

# Check persistent volume claims
kubectl get pvc -A

# View storage classes
kubectl get storageclass
```
