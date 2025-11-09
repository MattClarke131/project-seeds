# Talos Configuration

Configuring and bootstrapping the Talos Kubernetes cluster after VMs are deployed.

## Overview

## Steps
### Step 1: Install Talosctl
1. Install talosctl on your local machine.
**macOS:**
```bash
brew install siderolabs/tap/talosctl
```
2. Verify Installation
```bash
talosctl version --client
```

### Step 2: Generate Talos Configuration Files
1. Generate cluster configuration files from your local machine.
```bash
cd infrastructure/talos
talosctl gen config <cluster-name> https://10.0.10.10:6443
```

This creates three files:
- `controlplane.yaml` - Control plane node configuration
- `worker.yaml` - Worker node configuration
- `talosconfig` - Talosctl configuration file

**These files contain secrets!**

### Step 1: Generate Talos Configuration
Run these steps on your local machine where you have Talosctl installed.
These should be ran from the `infrastructure/talos` directory in this repo.

1. Generate cluster configuration files:
```bash
cd infrastructure/talos
talosctl gen config <cluster-name> https://10.0.10.10:6443
```
This creates the following files.
**These files contain secrets!**
- `controlplane.yaml` - Control plane node configuration
- `worker.yaml` - Worker node configuration
- `talosconfig` - Talosctl configuration file

### Step 3: Verify VM Connectivity
Verify you can reach the Talos API on the VMs. We can connect to the vms using their Tailnet IPs. Proxmox advertises a subnet through Tailscale for VMs to use.

```bash
talosctl --nodes 10.0.10.10 version --insecure
