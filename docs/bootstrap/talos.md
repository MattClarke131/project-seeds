# Talos setup

Preparing the Talos Linux disk image for Kubernetes node deployment.

## Overview
Talos is an immutable OS, meaning it is read-only and cannot be modified after deployment. Configuration is managed via a declarative YAML file that is applied at boot time.

Every node runs the `qemu-guest-agent` and `i915` system extensions (see `infrastructure/proxmox/opentofu/cluster.tf` / `locals.tf`). The extension set has to be baked into the **template** image (see Step 1) - adding an extension to `install.extensions` in Terraform's machine config does **not** retroactively apply to an already-installed node or to a fresh clone of an existing template. It only takes effect via a genuine reinstall: either `talosctl upgrade` against an already-running node, or (what we do here) rebuilding the template and destroying/recreating the VM so it clones fresh.

## Steps
### Step 1: Get Talos Linux Image
Run these steps on **each** proxmox host

1. Get the schematic ID for the extension set we want (`qemu-guest-agent` + `i915`) from the Image Factory:
```bash
curl -s -X POST https://factory.talos.dev/schematics \
  -H "Content-Type: application/json" \
  -d '{
    "customization": {
      "systemExtensions": {
        "officialExtensions": [
          "siderolabs/qemu-guest-agent",
          "siderolabs/i915"
        ]
      }
    }
  }'
```
This returns a schematic `id` (a stable hash of the extension list - independent of Talos version). As of the `livio` rebuild this was `d3dc673627e9b94c6cd4122289aa52c2484cddb31017ae21b75309846e257d30`. Re-run this if the extension list ever changes; the id will change too.

2. Download the image (`nocloud`, not `bare-metal`, because it includes cloud-init support which Talos uses for initial configuration - `raw.xz` format):
```bash
curl -L https://factory.talos.dev/image/<schematic-id>/<talos-version>/nocloud-amd64.raw.xz \
  -o /var/lib/vz/template/iso/talos-<talos-version>-nocloud-amd64.raw.xz
```
Pick `<talos-version>` deliberately (check https://github.com/siderolabs/talos/releases for current supported versions, and check the version isn't EOL - Talos generally supports the latest ~3 minor versions). Update `locals.talos_version` in `infrastructure/proxmox/opentofu/locals.tf` to match once every node in the fleet is actually on this version - not before.

3. Unpack the raw disk image:
```bash
unxz /var/lib/vz/template/iso/talos-<talos-version>-nocloud-amd64.raw.xz
```

### Step 2: Create VM template
Run these steps on **each** proxmox host

**NOTE:** Each node needs a unique template ID. The Proxmox cluster syncs VM IDs across nodes.
So we will need to increment the template ID for each node. (e.g., 10000, 20000, 30000, ...) - see `terraform.tfvars` for the current `template_vm_id` per host.

**If rebuilding an existing template** (not a fresh setup), destroy the old one first - safe as long as the running VMs are full ZFS clones, not linked clones (verify with `zfs list -o name,origin -t volume`; an empty `origin` column means full clone, safe to destroy the template independently):
```bash
qm destroy <template-id>
```

1. Create a VM template using the Talos raw disk image. Increment the `10000` ID for each node:

```bash
qm create 10000 \
  --name talos-template \
  --memory 4096 \
  --cores 4 \
  --net0 virtio,bridge=vmbr0 \
  --scsi0 local-zfs:0,import-from=/var/lib/vz/template/iso/talos-<talos-version>-nocloud-amd64.raw \
  --boot order=scsi0 \
  --scsihw virtio-scsi-pci \
  --bios ovmf \
  --machine q35 \
  --efidisk0 local-zfs:1,efitype=4m,pre-enrolled-keys=0 \
  --agent enabled=1 \
  --template
```

**`--machine q35` is required**, not optional, even if you don't need GPU passthrough on this particular host: PCIe passthrough (`hostpci` with `pcie=1`) only works on `q35` machine type, and this is set at template-creation time - it's not something Terraform or a later `qm set` can cleanly retrofit onto VMs already cloned from a `pc`/`i440fx` template. Missing this flag was the cause of a real passthrough failure during the `livio-w1` GPU work (silent until the VM was actually rebooted with `hostpci0` attached).

2. Resize template disk to 50GB. Run this on each host, incrementing each VM ID:
```bash
qm resize 10000 scsi0 50G
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
    template_id = 10000
  },
  {
    node_name        = "pve2"
    template_id = 20000
  },
  {
    node_name        = "pve3"
    template_id = 30000
  }
]
```

5. Any VMs cloned from this template before the rebuild are unaffected (full clones are independent), but won't have the new image until they're individually destroyed and recreated (`tofu apply -replace='proxmox_virtual_environment_vm.worker["<key>"]'` or `.control_plane["<key>"]`) so they clone fresh from the corrected template. Control plane nodes need extra care - check `talosctl etcd status` first; recreating the current etcd leader forces a leader election, which is safe but should be deliberate, not batched in with worker rebuilds.
