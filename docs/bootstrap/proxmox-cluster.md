# Proxmox Bootstrap Guide

Configuring Proxmox VE

## Step 1: Install Proxmox VE
1. Create a bootable USB drive with the Proxmox VE ISO from (proxmox)[proxmox.com].
2. Boot machine and install Proxmox VE.
  - Set hostname (ex: `pve1.example.local`)

## Step 2: Configure Network
### Step 2.1: Reserve IP Address on DHCP Server
1. Get MAC address: `ip link show` (Look for physical interface, usually `enpXsY` or `ethX`)
2. Reserve IP address on DHCP server for the MAC address.

### Step 2.2: Configure static IP Address on Proxmox VE
1. Edit the network configuration file: `nano /etc/network/interfaces`
```
auto vmbr0
iface vmbr0 inet static
    address 192.168.x.y/24   # Use your reserved IP address
    gateway 192.168.x.1      # Use your network gateway
    bridge-ports enpXsY      # Replace with your physical interface
    bridge-stp off
    bridge-fd 0
```
2. Restart networking service: `systemctl restart networking`
3. Verify connectivity: `ping 9.9.9.9`

## Step 3: Configure Proxmox Repositories
### Step 3.1: Disable Enterprise Repos
1. Comment out enterprise sources:
```bash
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
```
2. Handle .sources files:
```bash
mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.sources.disabled
mv /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/ceph.sources.disabled
```

### Step 3.2: Add No-Subscription Repo
```bash
## Adds the no-subscription repository if it doesn't already exist
grep -qxF 'deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' /etc/apt/sources.list || echo 'deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' >> /etc/apt/sources.list
```

### Step 3.3: Update and Upgrade
```bash
apt update && apt full-upgrade -y
```

## Step 4: Configure hosts
1. Add an entry for each node in `/etc/hosts`:
```
# Include self and other nodes
192.168.x.y pve1.example.local pve1
192.168.x.z pve2.example.local pve2
```
2. Test connection
```bash
ping 192.168.x.y
ping pve1.example.local
```

## Optional Step: Setup SSH Keys
1. Generate SSH keys on your local machine (if not already done)
2. Copy public key to Proxmox node
3. Disable password authentication in `/etc/ssh/sshd_config`

## Step 5: Create Proxmox Cluster
### Step 5.1: (first node only) Initialize Cluster
```bash
pvecm create my-cluster
```
### Step 5.2: (other nodes) Join Cluster
```bash
pvecm add 192.168.x.y
```
or
```bash
pvecm add pve1.example.local
```
### Step 5.3: Verify Cluster
```bash
pvecm status
pvecm nodes
```

### Step 6: Enable Snippets Storage
On each proxmox node, run the following commands:
1. Create snippets directory
```bash
mkdir -p /var/lib/vz/snippets
```

2. Add snippets storage via CLI
```bash
pvesm set local --content backup,iso,vztmpl,snippets
```
