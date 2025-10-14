# ADR: Kubernetes Distribution and Virtualization Layer
## Date
2025-10-14

## Status
Accepted

## Context
The primary goal for this project is to learn. We will be hosting docker container in a kubernetes cluster. The cluster will be hosted on a virtualized environment. We have already decided to use Proxmox as our virtualization layer. We can create full VMs or LXC containers.

1. We need to decide on a kubernetes distribution (k8s, k3s).
2. We need to decide on a virtualization layer (VMs or LXC).
3. We need to decide on an operating system for the nodes (Ubuntu, Debian, CentOS, Talos).

## Requirements
- Multi-node kubernetes cluster with at least 3 control plane nodes.

## Decision
### Talos on VMs on k8s
We will use Talos as our operating system for the nodes. Talos is a modern, secure, and minimal operating system designed specifically for running Kubernetes. It is immutable, meaning that it cannot be modified once it is deployed. From a learning perspective, The concepts of immutable infrastructure and declarative configuration are important to understand in modern cloud-native environments. Talos enforces these concepts, providing a practical way to learn and apply them. We lose the ability to ssh into the nodes, which forces us to use good kubernetes practices for managing the cluster.

We will use VMs as our virtualization layer. Talos does not support LXC containers. VMs provide better isolation and security compared to LXC containers.

We will use k8s as our kubernetes distribution. k8s is the most widely used kubernetes distribution and has the most features. From a learning perspective, k8s is the most widely used kubernetes distribution and has the most features. Learning k8s will provide a solid foundation for understanding kubernetes concepts and architecture.

### Summary

## Alternatives Considered
#### K3s
K3s is a lightweight kubernetes distribution. While it would be easier to set up and manage, it is not as widely used as k8s. From a learning perspective, k3s is a good choice for learning the basics of kubernetes. However, it does not provide the same level of complexity and features as k8s.

#### LXC
LXC containers are lightweight and easy to set up. However, they do not provide the same level of isolation and security as VMs. Additionally, Talos does not support LXC containers.

#### Ubuntu/Debian/CentOS
Traditional operating systems are widely used and have a large community. However, they are not designed specifically for running kubernetes. They require more maintenance and management compared to Talos. From a learning perspective, traditional operating systems are a good choice for learning general Linux administration. However, they do not provide the same level of focus on kubernetes concepts and architecture as Talos.

