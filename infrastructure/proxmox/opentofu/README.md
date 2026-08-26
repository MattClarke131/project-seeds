# Proxmox Kubernetes Cluster

OpenTofu configuration for provisioning Talos Linux VMs on Proxmox cluster.

## Provisioning

Deploy the cluster VMs:
```bash
tofu init
tofu apply
```

## Bootstrap Cluster

The talosconfig is rendered on demand from OpenTofu state via `tofu output` —
it is not written to disk automatically. Materialize it straight to
talosctl's default lookup path first:
```bash
tofu output -raw talosconfig > ~/.talos/config
```
Re-run that whenever the cluster's certs are regenerated (e.g. an apply that
recreates `talos_machine_secrets`), or `~/.talos/config` goes stale and
`talosctl` fails with `x509: certificate signed by unknown authority`.

Initialize Kubernetes and generate kubeconfig:
```bash
# Bootstrap etcd and control plane
talosctl bootstrap --nodes 10.0.10.30

# Generate kubeconfig for kubectl access
talosctl kubeconfig --nodes 10.0.10.30 --force

# Verify cluster
kubectl get nodes
```
