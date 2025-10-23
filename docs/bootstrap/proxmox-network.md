# Proxmox network guide

Configuring Proxmox SDN (Software Defined Networking) for Kubernetes cluster VMs.

## Overview

What SDN provides:
- VMs get IPs from 10.0.10.0/24 subnet
- VMs are invisible to home network devices
- Automatic configuration across all cluster nodes

## Network Architecture
```
Physical Network (Management Layer)
├── Node 1 (Physical IP) ─┐
├── Node 2 (Physical IP) ──┤ SDN Routing Layer
└── Node 3 (Physical IP) ──┘
         ↓
    SDN Zone (Simple)
         ↓
  Virtual Network (10.0.10.0/24)
  ├── K8s VMs see each other via routing
  └── Isolated from physical network
```

See [ADR-002 Network Bridge for Kubernetes Cluster](../docs/adr/002-network-bridge-for-kubernetes-cluster.md) for reasoning.

## Prerequisites
- Completed [Proxmox Cluster Setup](./proxmox-cluster.md)

## Configuration Steps

### Step 1: Create SDN Zone
On one Proxmox node, run:
```bash
pvesh create /cluster/sdn/zones \
  --type vxlan \
  --zone k8sZone \
  --peers "<node1-ip>,<node2-ip>,<node3-ip>"
```

### Step 2: Create Virtual Network (VNet)
```bash
pvesh create /cluster/sdn/vnets \
  --vnet k8sVNet \
  --zone k8sZone \
  --tag 100 \
  --alias "<optional-alias>"
```

**Parameters:**
- `--vnet`: Network name (k8sVNet)
- `--zone`: The VXLAN zone created in Step 2
- `--tag`: VXLAN Network Identifier (VNI) - must be unique
- `--alias`: Friendly name for the network

### Step 3: Create Subnet
```bash
pvesh create /cluster/sdn/vnets/k8sVNet/subnets \
  --subnet 10.0.10.0/24 \
  --type subnet \
  --gateway 10.0.10.1 \
  --snat 1
```

**Parameters:**
- `--subnet`: IP range for VMs (10.0.10.0/24 provides 254 usable addresses)
- `--type`: Must be "subnet"
- `--gateway`: Gateway IP address
- `--snat`: Enable Source NAT for outbound traffic (1 = enabled)

### Step 4: Apply SDN Configuration
```bash
pvesh set /cluster/sdn
```

### Step 5: Configure Gateway IP
VXLAN zones require manual gateway IP configuration on each node:
On each Proxmox node, run:
```bash
ip addr add 10.0.10.1/24 dev k8sVNet
```

### Step 6: Verify Configuration
Check that the network is configured correctly on each node:
```bash
# Verify the k8sVNet interface exists
ip link show | grep k8sVNet

# Verify the gateway IP is assigned
ip addr show k8sVNet | grep "inet "

# Check routing table
ip route | grep 10.0.10
```

### (Optional) Step 7: Advertise the Network on Tailnet
If using Tailscale, advertise the new subnet from one Proxmox node:
```bash
tailscale up --login-server <headscale address> --advertise-routes=10.0.10.0/24 --accept-routes --ssh
```
On your local machine, accept the advertised route:
```bash
tailscale up --accept-routes
```
or via the tailscale app settings.
