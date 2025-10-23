# Terraform Bootstrapping

Configuring Terraform to automate Proxmox VM provisioning for Kubernetes cluster.

## Prerequisites
- Proxmox cluster operational
- SDN configured with k8sVNet (10.0.10.0/24)
- Tailscale subnet configured (if using Tailnet)
- Terraform installed on local machine ([install guide](https://developer.hashicorp.com/terraform/install))
- Talos configuration files generated ([see Talos guide](./talos.md))

## Overview

What Terraform setup provides:
- Infrastructure as code for VM provisioning
- Reproducible environment setup
- Version control for infrastructure changes

## Architecture
```
Terraform (Local Machine)
    ↓ API calls over HTTPS
Proxmox API (Token Auth)
    ↓ Creates resources
Proxmox Cluster
    ├── VM on node 1 (k8s-cp-1)
    ├── VM on node 2 (k8s-cp-2)
    └── VM on node 3 (k8s-cp-3)
         ↓ Network attachment
    SDN: k8sVNet (10.0.10.0/24)
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
pveum role add TerraformRole -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Audit VM.PowerMgmt VM.GuestAgent.Audit Datastore.AllocateSpace Datastore.Audit SDN.Use"

```

3. Assign role to user for entire cluster
```bash
pveum aclmod / -user terraform@pve -role TerraformRole
```

4. API token (save the output!)
```bash
pveum user token add terraform@pve terraform-token --privsep 0
```
**Note**: This command will output the token value only once.

5. Verify API access
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

2. Init terraform
```bash
cd infrastructure/terraform/proxmox
terraform init
```
3. Validate configuration
```bash
terraform validate
terraform plan
```

