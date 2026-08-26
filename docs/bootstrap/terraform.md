# OpenTofu Bootstrapping

Configuring OpenTofu to automate Proxmox VM provisioning for Kubernetes cluster.

> This project uses [OpenTofu](https://opentofu.org/) (the `tofu` CLI), not
> Terraform — see [ADR 001](/docs/adr/001-kubernetes-distribution-and-virtualization-layer.md).
> The `terraform` CLI is drop-in compatible if you already have it installed,
> but commands below use `tofu`.

## Prerequisites
- Proxmox cluster operational
- SDN configured with k8sVNet (10.0.10.0/24)
- Tailscale subnet configured (if using Tailnet)
- OpenTofu installed on local machine ([install guide](https://opentofu.org/docs/intro/install/))
- Talos templates created on each Proxmox node ([see Talos guide](./talos.md))

## Overview

What the OpenTofu setup provides:
- Infrastructure as code for VM provisioning
- Automated Talos configuration and cluster bootstrapping
- Reproducible environment setup
- Version control for infrastructure changes

## Architecture
```
OpenTofu (Local Machine)
    ↓ API calls over HTTPS
    ├─→ Proxmox API (Token Auth)
    │       ↓ Creates VMs
    │   Proxmox Cluster (3 control planes, 6 workers)
    │       ↓ Network: k8sVNet (10.0.10.0/24)
    │
    └─→ Talos API (Port 50000)
            ↓ Applies machine configs
        Talos Linux VMs
            ↓ Bootstraps
        Kubernetes Cluster
```

## Configuration Steps

### Step 1: Create Proxmox API User
In a proxmox node shell:

1. Create dedicated Terraform user
```bash
pveum user add terraform@pve --comment "Terraform automation user"
```

2. Create role with VM management permissions
```bash
pveum role add TerraformRole -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Audit VM.PowerMgmt VM.GuestAgent.Audit Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit SDN.Use"
```

3. Assign role to user for entire cluster
```bash
pveum aclmod / -user terraform@pve -role TerraformRole
```

4. Assign role to user for local storage (required for snippet uploads)
```bash
pveum aclmod /storage/local -user terraform@pve -role TerraformRole
```

5. API token (save the output!)
```bash
pveum user token add terraform@pve terraform-token --privsep 0
```
**Note**: This command will output the token value only once.

6. Verify API access
```bash
# Replace xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx with your actual token secret
# Replace <ip> with your Proxmox node IP
curl -k -H "Authorization: PVEAPIToken=terraform@pve!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" https://<ip>:8006/api2/json/cluster/resources
```

### Step 2:  Initialize Terraform
1. Create `terraform.tfvars` with your proxmox connection details. Use terraform.tfvars.example as a template.
```hcl
proxmox_endpoint     =
proxmox_api_token    =
proxmox_token_secret =

proxmox_nodes = [
  {
    node_name        = "pve1"
    template_id = 9000
  },
  {
    node_name        = "pve2"
    template_id = 9001
  },
  {
    node_name        = "pve3"
    template_id = 9002
  }
]
```
`terraform.tfvars` is gitignored as it contains secrets

2. Init OpenTofu
```bash
cd infrastructure/proxmox/opentofu
tofu init
```
3. Validate configuration
```bash
tofu validate
tofu plan
```

### Step 3: Apply OpenTofu Configuration
1. Apply configuration to create VMs
```bash
tofu apply
```

2. Verify VMs created in Proxmox UI or via CLI
```bash
pvesh get /cluster/resources --type vm
```

### Step 4: Post-Deployment
1. Wait 2-3 minutes for VMs to fully boot
```bash
ping -c 3 10.0.10.10
```

The commands below assume `~/.talos/config` (talosctl's default config)
already has a working context for this cluster. If `talosctl` fails with
`x509: certificate signed by unknown authority`, that context is stale or
missing — pull a fresh one straight from OpenTofu state:
```bash
tofu output -raw talosconfig > ~/.talos/config
```

2. Bootstrap Kubernetes cluster using Talosctl
```bash
talosctl bootstrap --nodes 10.0.10.10
```

3. Wait 1-2 minutes, then verify cluster health
```bash
talosctl --nodes 10.0.10.10 health
talosctl --nodes 10.0.10.10 etcd members
```

4. Generate kubeconfig for kubectl access
```bash
talosctl kubeconfig --nodes 10.0.10.10
```
