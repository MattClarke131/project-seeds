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

## Recovery: Cleaning up orphaned vm configs
```bash
## Cleaning Up Orphaned VM Configs

If you manually destroyed VMs or have stale state, clean up config files:
```bash
ssh root@<node1> "rm -f /etc/pve/nodes/nicholas/qemu-server/{101,211,212}.conf"
ssh root@<node2> "rm -f /etc/pve/nodes/livio/qemu-server/{100,201,202}.conf"
ssh root@<node3> "rm -f /etc/pve/nodes/razlo/qemu-server/{102,221,222}.conf"
```

