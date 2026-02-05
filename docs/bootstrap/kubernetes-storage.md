# Kubernetes Storage Setup

Configuring persistant storage for the Kubernetes cluster using NFS from TrueNAS.

## Network Topology Note
Kubernetes pods (10.0.10.0/24) reach TrueNAS (192.168.1.x) through NAT on Proxmox nodes. From TrueNAS's perspective, connections appear to come from the Proxmox nodes' IPs (192.168.1.x), not from pod IPs. This is why NFS shares must allow the 192.168.1.0/24 subnet, not 10.0.10.0/24.


### Step 1: Configure TrueNAS NFS Storage
1. **Create ZFS dataset** for Kubernetes storage
2. **Create NFS share**
3. **Configure share permissions**
4. **Enable NFS service**
