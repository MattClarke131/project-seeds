# snakAssistant - Home Assistant OS on Proxmox

OpenTofu module for provisioning a Home Assistant OS VM on `snakAssistant`.

## Prerequisites

- Proxmox installed on `snakAssistant`
- SSH key copied to `snakAssistant`: `ssh-copy-id root@100.64.0.17`
- Proxmox API token created (see below)

## One-Time Bootstrap

These steps must be run manually before `tofu apply`.

### 1. Create Proxmox API Token

In the Proxmox web UI at `https://100.64.0.17:8006`:

1. Datacenter → Users → Add
   - User name: `terraform`, Realm: `pve`
2. Datacenter → Permissions → Add → User Permission
   - Path: `/`, User: `terraform@pve`, Role: `Administrator`, Propagate: checked
3. Datacenter → API Tokens → Add
   - User: `terraform@pve`, Token ID: `terraform-token`, Privilege Separation: **unchecked**
   - Copy the secret immediately into Bitwarden and `terraform.tfvars`

### 2. Download and Import HAOS Image

SSH into `snakAssistant` and run:
```bash
# Download the HAOS image
wget -P /tmp https://github.com/home-assistant/operating-system/releases/download/17.1/haos_ova-17.1.qcow2.xz

# Decompress
xz -d /tmp/haos_ova-17.1.qcow2.xz

# Import into VM (run after tofu apply creates the VM)
/usr/sbin/qm importdisk 100 /tmp/haos_ova-17.1.qcow2 local
/usr/sbin/qm set 100 --scsihw virtio-scsi-pci --scsi0 local:100/vm-100-disk-2.raw,discard=on
```

> **Note:** The disk name (`vm-100-disk-2.raw`) may differ if the VM has been reprovisioned.
> Check with `ls /var/lib/vz/images/100/` and update `main.tf` accordingly.

## Deploy
```bash
cp terraform.tfvars.example terraform.tfvars
# Fill in proxmox_token_secret
tofu init
tofu apply
```

## Accessing Home Assistant

- Local: `http://192.168.0.11:8123`
- Tailnet: via Tailscale add-on after first boot (see below)

## Post-Boot Setup

1. Complete the Home Assistant onboarding at `http://192.168.0.11:8123`
2. Install the Tailscale add-on from the Add-on Store for remote access
3. Configure backups to TrueNAS over Tailscale
