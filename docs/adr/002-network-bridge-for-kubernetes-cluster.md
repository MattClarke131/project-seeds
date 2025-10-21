# ADR: Network Bridge for Kubernetes Cluster
## Status
Accepted

## Context
A kubernetes cluster requires network connectivity between its nodes and the outside world. In a virtualized environment like Proxmox, we need to decide how to configure the network bridge for the kubernetes cluster.

We currently have vmbr0 as our default bridge in Proxmox, which is connected to the physical network interface (192.168.1.0/24).

### Learning Goals
- Understand network segmentation and isolation in a virtualized environment
- Learn about overlay networking concepts
- Practice with Software Defined Networking (SDN)

### Current Infrastructure Constraints
Our existing router does not support:
- Multiple subnets/DHCP pools
- VLANs

This limits our ability to create physically isolated networks without using overlay/routing solutions

# Original Decision and Reversal
We initially attempted to create isolated bridges (vmbr1) manually on each node with NAT routing. However, we discovered that VMs on different Proxmox nodes could not communicate with each other without complex routing configuration. We reconsidered using Proxmox SDN, which solves all our problems.

## Decision
### Proxmox SDN with Simple Zone and 10.0.10.0/24 Subnet
We will use Proxmox's built-in Software Defined Networking (SDN) feature to create an isolated virtual network for the kubernetes cluster VMs.

VMs access external networks via SNAT through Proxmox hosts.

Traffic is routed through Proxmox hosts over physical network.

**Network Architecture:**
Physical Network (192.168.1.0/24)
├── Node 1 (Physical IP) ─┐
├── Node 2 (Physical IP) ──┤ SDN Routing Layer
└── Node 3 (Physical IP) ──┘
         ↓
    SDN Zone (Simple)
         ↓
  Virtual Network (10.0.10.0/24)
  ├── K8s VMs communicate via routing
  └── Isolated from physical network

### Benefits
- Cluster-managed configuration (automatic propagation to all host nodes)
- VMs on different phsyical hosts can communicate
- Network isolation from physical network
- Simplified IP address management
- Closer to production-like environment for learning purposes

### Tradeoffs:
- Proxmox-specific feature, limiting portability of skills learned.
- Routing overhead compared to direct Layer 2 (negligible for our use case)
- Abstraction hides some networking fundamentals

## IP Address Management
Each Proxmox host has its own isolated vmbr1 bridge. There is no coordination of ip addresses between hosts. To avoid collisions, we assign ip addresses in a structured manner with terraform. We assign the same gateway on each host (10.0.10.1)

IP addresses will be statically assigned via terraform configuration:
- Control plane nodes: 10.0.10.11, 10.0.10.12, 10.0.10.13
- Worker nodes: 10.0.10.100+ (as needed)
- Gateway: 10.0.10.1 (same on all hosts)

IP address collisions are avoided through structured assignment.

## Alternatives Considered
### Using the Default Bridge (vmbr0)
Using vmbr0 for the kubernetes cluster would allow the nodes to have direct access to the physical network, making it easier to communicate with other devices on the network.

However, this approach offers no network isolation: It becomes harder to declaratively manage the cluster's network configuration.

**Rejected because:**
- No network isolation between k8s cluster traffic and other traffic
- IP address management becomes more complex
- Less production-like environment for learning purposes

### Manual Bridge Configuration (vmbr1) with NAT
We initially attempted to manually create isolated bridges (vmbr1) on each Proxmox node with NAT routing.

**Rejected because:**
- VMs on different Proxmox nodes could not communicate without complex routing configuration.
- Required manual configuration on each node
