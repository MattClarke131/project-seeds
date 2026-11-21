# Headscale

Headscale is the self-hosted Tailscale control server for the tailnet. It runs on a DigitalOcean droplet named `attlerock`, managed by the OpenTofu module in `opentofu/`.

## What lives where

- **In git:** the droplet, reserved IP, firewall, SSH key, cloud-init and `headscale-config.yaml`.
- **Out of git, restored by hand:**
  - `/var/lib/headscale/db.sqlite`: nodes, users and pre-auth keys.
  - `/var/lib/headscale/noise_private.key`: losing this forces every node to re-register.
  - `/etc/headscale/acl.json`: the tailnet policy.
- **DNS:** `headscale.labmatt.com` lives in `infrastructure/cloudflare/opentofu` as `headscale_ipv4`. Point it at the reserved IP, never the droplet IP.

## Design notes

- **TLS:** Headscale terminates TLS itself with Let's Encrypt (HTTP-01 on port 80). The first HTTPS request after DNS resolves triggers issuance.
- **Patching:** unattended-upgrades installs security updates and reboots at 09:00 UTC when needed. A reboot only pauses the control plane; existing tailnet connections keep working.
- **First boot:** cloud-init installs Headscale but leaves it disabled until state is restored.
- **Drift:** `user_data` and `image` are in `ignore_changes`, so a plain `tofu apply` never rebuilds the droplet. Rebuilds are explicit (see below).

## Setup

`opentofu/terraform.tfvars` (gitignored):

```hcl
do_token       = "<DigitalOcean read/write token>"
ssh_public_key = <<-EOT
ssh-ed25519 AAAA... matt
EOT
```

```sh
cd infrastructure/headscale/opentofu
tofu init
tofu plan
```

The SSH key already exists in the DigitalOcean account, so a fresh state must import it before applying. Otherwise the apply fails with "SSH Key is already in use". Find the ID by fingerprint (`ssh-keygen -l -E md5 -f ~/.ssh/id_ed25519.pub`) in the account's key list, then:

```sh
tofu import digitalocean_ssh_key.homelab <key id>
```

## Cutover from the hand-built droplet

The current `attlerock` (Ubuntu 25.04, nginx + certbot) was built by hand and isn't in state. This runbook builds the new droplet beside it.

1. Build the new droplet and reserved IP.
   ```sh
   tofu apply
   NEW=$(tofu output -raw droplet_ipv4)
   ssh matt@$NEW cloud-init status --wait
   ```
2. Stop Headscale on the old droplet and copy its state to the Mac. The control plane is down from here until step 5.
   ```sh
   ssh attlerock 'sudo systemctl stop headscale && sudo tar -C /var/lib -czf /tmp/headscale-state.tgz headscale && sudo cp /opt/headscale/config/acl.json /tmp/ && sudo chown matt /tmp/headscale-state.tgz /tmp/acl.json'
   scp attlerock:/tmp/headscale-state.tgz attlerock:/tmp/acl.json ~/backups/headscale/
   ```
3. Restore onto the new droplet.
   ```sh
   scp ~/backups/headscale/headscale-state.tgz ~/backups/headscale/acl.json matt@$NEW:/tmp/
   ssh matt@$NEW 'sudo tar -C /var/lib -xzf /tmp/headscale-state.tgz && sudo chown -R headscale:headscale /var/lib/headscale && sudo install -o root -g headscale -m 0640 /tmp/acl.json /etc/headscale/acl.json && sudo rm /tmp/headscale-state.tgz'
   ```
4. Point DNS at the reserved IP. Set `headscale_ipv4` in `infrastructure/cloudflare/opentofu/variables.tf` to `tofu output -raw reserved_ipv4`, then apply that module.
5. Start Headscale and check it.
   ```sh
   ssh matt@$NEW 'sudo systemctl enable --now headscale'
   curl -fsS https://headscale.labmatt.com/health
   ssh matt@$NEW 'headscale nodes list'
   tailscale status
   ```
6. Update the `attlerock` alias in `~/.ssh/config` to the reserved IP.
7. After a week of normal use, destroy the old droplet in the DigitalOcean console.

**Rollback (until step 7):** revert `headscale_ipv4`, apply Cloudflare, then `ssh <old ip> sudo systemctl start headscale`. Changes made on the new server since the cutover are lost.

## Changing the Headscale config

Edit `opentofu/headscale-config.yaml`, render it, then push it:

```sh
cd infrastructure/headscale/opentofu
echo 'templatefile("headscale-config.yaml", { headscale_hostname = "headscale.labmatt.com" })' | tofu console | sed '1d;$d' > /tmp/headscale-config.yaml
scp /tmp/headscale-config.yaml attlerock:/tmp/config.yaml
ssh attlerock 'sudo install -m 0644 /tmp/config.yaml /etc/headscale/config.yaml && sudo systemctl restart headscale'
```

## Upgrading Headscale

Bump `headscale_version` and `headscale_deb_sha256` (from the release's `checksums.txt`) so rebuilds match. Then install the same `.deb` on the live box with `sudo dpkg --force-confold -i`. Read the release notes first, since minor releases can rename config keys.

## Rebuilding the droplet

Back up `/var/lib/headscale` and `/etc/headscale/acl.json` first (step 2 above). Then:

```sh
tofu apply -replace=digitalocean_droplet.headscale
```

The reserved IP moves to the new droplet automatically. Restore state (step 3) and start Headscale (step 5). DNS doesn't change.
