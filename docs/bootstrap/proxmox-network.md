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
  - **Note** This flag may not work with VXLAN zones. We later manually configure NAT on the gateway node

### Step 4: Apply SDN Configuration
```bash
pvesh set /cluster/sdn
```

### Step 5: Configure Gateway IP
VXLAN zones require manual gateway IP configuration on each node. This is temporary and will be lost on reboot.
On each Proxmox node, run:
```bash
ip addr add 10.0.10.1/24 dev k8sVNet
```

### Step 6: Configure NAT for Internet Access
VXLAN zones require manual NAT configuration for outbound internet access. We require gateway configuration on all nodes for high availability.

1. On each proxmox node, edit `/etc/network/interfaces` and add the block below.
**Note:** Increment the `metric` value on each node to set routing priority (lower = higher priority). Metric ensure a primary gateway, with automatic failover to other nodes.
```bash
# K8s VXLAN Gateway Configuration
auto k8sVNet
iface k8sVNet inet static
        address 10.0.10.1/24
        metric 100
        post-up iptables -A FORWARD -i k8sVNet -o vmbr0 -j ACCEPT
        post-up iptables -A FORWARD -i vmbr0 -o k8sVNet -m state --state RELATED,ESTABLISHED -j ACCEPT
        post-up iptables -t nat -A POSTROUTING -s 10.0.10.0/24 ! -d 10.0.10.0/24 -o vmbr0 -j MASQUERADE
```

2. Enable IP forwarding
```bash
# Check if already enabled
cat /proc/sys/net/ipv4/ip_forward

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

### Step 7: Verify Configuration
Check that the network is configured correctly on each node:
```bash
# Verify the k8sVNet interface exists
ip link show | grep k8sVNet

# Verify the gateway IP is assigned
ip addr show k8sVNet | grep "inet "

# Check routing table
ip route | grep 10.0.10
```

### (Optional) Step 8: Advertise the Network on Tailnet
If using Tailscale, advertise the new subnet from **each** Proxmox node:
```bash
tailscale up --login-server <headscale address> --advertise-routes=10.0.10.0/24 --accept-routes --ssh
```
On your local machine, accept the advertised route:
```bash
tailscale up --accept-routes
```
or via the tailscale app settings.
