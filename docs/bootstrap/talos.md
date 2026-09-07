# Talos setup

Preparing the Talos Linux disk image for Kubernetes node deployment.

## Overview
Talos is an immutable OS, meaning it is read-only and cannot be modified after deployment. Configuration is managed via a declarative YAML file that is applied at boot time.

### Who owns which extensions

`infrastructure/proxmox/opentofu/cluster.tf` resolves each role's extension set into a Talos Image Factory schematic and feeds it into `machine.install.image`:
- Control planes: `qemu-guest-agent`, `iscsi-tools`
- Workers: `qemu-guest-agent`, `iscsi-tools`, `i915` (see `locals.tf`)

`i915` is the Intel GPU driver - it's universal across all workers even though only `k8s-livio-w1` actually has a GPU passed through (see `services/jellyfin/README.md` and the GPU passthrough section below).

Talos reinstalls itself to `install.image` on first boot **regardless of what the template already had**, so `install.image`/`cluster.tf` is the sole source of truth for which extensions actually end up running. That means no extension - not even `qemu-guest-agent` - needs to be baked into the template itself.

The **template** (Step 1 below) is a fully generic, stock Talos image with no extensions baked in at all. It only needs to boot and start talking to Terraform/the Talos API; `install.image` fully owns what's actually installed. This means `vms.tf`'s VM resources can't rely on the QEMU guest agent responding quickly - it isn't present until *after* Talos's own reinstall completes - so they don't have an `agent` block at all. Nothing needs agent-discovered IPs anyway: every node's static IP is already known up front (`locals.control_plane_nodes`/`worker_nodes`). See #16.

If the extension set in `cluster.tf` ever changes, that takes effect fleet-wide the next time each node goes through an install cycle (`talosctl upgrade`, or a destroy/recreate against the current template) - **no template rebuild required**.

## Steps
### Step 1: Get Talos Linux Image
Run these steps on **each** proxmox host

1. Get the schematic ID for a stock, no-extensions image. The Image Factory always needs a schematic id, even for a plain image, so resolve one with an empty extension list - the template is fully generic; `cluster.tf`'s `install.image` is the sole source of truth for which extensions actually end up running (see "Who owns which extensions" above):
```bash
curl -s -X POST https://factory.talos.dev/schematics \
  -H "Content-Type: application/json" \
  -d '{"customization": {"systemExtensions": {"officialExtensions": []}}}'
```
This returns a schematic `id`. It's stable across Talos versions as long as the (empty) extension list doesn't change, so you only need to do this once.

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
  --cpu host \
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

**`--cpu host` matters even though Terraform's `clone` resource sets it again on
every real fleet VM** (`cpu.type = "host"` in `vms.tf`, so production nodes are
unaffected either way): a VM cloned straight from this template with plain
`qm clone` - e.g. for scratch testing - silently inherits the template's own
CPU model instead, defaulting to `kvm64` if unset here. `kvm64` boots Talos
1.13's kernel into an immediate panic (`This program can only be run on
AMD64 processors`) with no indication why. Set it on the template so a
manual clone behaves the same as a Terraform-managed one.

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

## GPU passthrough (Proxmox `hostpci`)
Separate from the Talos image entirely - see `services/jellyfin/README.md` and `infrastructure/proxmox/opentofu/vms.tf` (`gpu_passthrough` resource / `local.gpu_passthrough_worker_key`) for how the physical GPU gets attached to `k8s-livio-w1` specifically. Two gotchas worth knowing:
- The Terraform provider's native `hostpci` block doesn't work with API tokens (Proxmox bug - see comments in `vms.tf`), so it's applied via a `qm set` provisioner instead.
- `hostpci` is not hot-pluggable - setting it via `qm set` on an already-running VM updates the config but doesn't attach the device until a full `qm stop`/`qm start` (not just an in-guest reboot).
