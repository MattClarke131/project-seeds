# Adding Nodes to a tailnet Managed by Headscale
1. Install Tailscale
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```
2. Authenticate Tailscale
```bash
tailscale up --login-server <headscale-address> --ssh
```
3. Enable tailscaled on boot
```bash
systemctl enable tailscaled
```
3. Register node on control plane. Update config acls.json and Restart headscale.
```bash
user@headscale $ systemctl restart headscale
```
5. Verify every node can ping each other using Tailscale IPs and local IPs
```bash
tailscale status
```
6. Enable ipv6 forwarding on each node
```bash
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p
```
