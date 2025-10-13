# Tailscale/Headscale Down

## Troubleshooting
### Symptoms
- Can't ping 100.64.x.x addresses
- `tailscale status` shows errors or no peers
- SSH via Tailscale hostnames fails

### Diagnosis
#### Check local tailscale status
```bash
systemctl status tailscaled
journalctl -u tailscaled -n 50
```

#### Check headscale server status
```bash
ssh user@headscale-server
sudo systemctl status headscale
sudo journalctl -u headscale -n 50
```

### Recovery
#### If local tailscale is stuck
```bash
# On local machine
sudo tailscale down
sudo tailscale up
```
#### If local tailscaled service is not running
```bash
# On local machine
sudo systemctl restart tailscaled
```
#### If headscale is down
```bash
# On control server
sudo systemctl restart headscale
```

## Terraform Workaround
For terraform actions, you can bypass Tailscale **LOCALLY** by using the local network interface.
```bash
terraform apply -var="proxmox_api_url=https://192.168.x.y:8006/api2/json"
```
