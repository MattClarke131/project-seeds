# Talos setup

Preparing the Talos Linux disk image for Kubernetes node deployment.

## Overview
Talos is an immutable OS, meaning it is read-only and cannot be modified after deployment. Configuration is managed via a declarative YAML file that is applied at boot time.

We use the QEMU guest agent extension to enable better communication between the Talos VM and Proxmox.

## Steps
### Step 1: Get Talos Linux Image
Run these steps on **each** proxmox host

1. Get a talos image from https://factory.talos.dev/
- nocloud-amd64
- Latest stable version
- Include QEMU guest agent
- skip customization
- raw.xz format

We choose nocloud instead of bare metal because it includes cloud-init support which Talos uses for initial configuration. bare metal images are more useful for single deployments on physical hardware.

2. Download the image:
```bash
wget <talos-image-url> -O /var/lib/vz/template/iso/nocloud-amd64.raw.xz
```

3. Unpack the raw disk image:
```bash
unxz /var/lib/vz/template/iso/nocloud-amd64.raw.xz
```

### Step 2: Create VM template
Run these steps on **each** proxmox host

**NOTE:** Each node needs a unique template ID. The Proxmox cluster syncs VM IDs across nodes.
So we will need to increment the template ID for each node. (e.g., 9000, 9001, 9002, ...)
1. Create a VM template using the Talos raw disk image. Increment the `9000` ID for each node:

```bash
qm create 9000 \
  --name talos-control-plane-template \
  --memory 2048 \
  --cores 1 \
  --net0 virtio,bridge=k8sVNet \
  --scsi0 local-zfs:0,import-from=/var/lib/vz/template/iso/nocloud-amd64.raw \
  --boot order=scsi0 \
  --scsihw virtio-scsi-pci \
  --bios ovmf \
  --efidisk0 local-zfs:1,efitype=4m,pre-enrolled-keys=0 \
  --agent enabled=1 \
  --template
```

2. Resize template disk to 50GB. Run this on each host, incrementing each VM ID:
```bash
qm resize 9000 scsi0 50G
```

3. Verify the templates:
```bash
pvesh get /cluster/resources --type vm
```

4. Update terraform.tfvars with the correct template IDs, and node_names for each node:
```hcl
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
