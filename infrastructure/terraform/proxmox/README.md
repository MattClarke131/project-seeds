## Recreating the cluster
# 1. Apply new cluster
```bash
terraform apply
```

# 2. Bootstrap the cluster (initializes etcd and k8s control plane)
```bash
talosctl bootstrap --nodes 10.0.10.10 --talosconfig ./talosconfig
```

# 3. Generate fresh kubeconfig (new cluster = new certs)
```bash
talosctl kubeconfig --nodes 10.0.10.10 --talosconfig ./talosconfig --force
```

# 4. Verify
```bash
kubectl get nodes
```
