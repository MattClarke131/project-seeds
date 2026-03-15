# qbittorrent-vpn

qBittorrent running behind a Gluetun VPN sidecar (AirVPN + WireGuard).

## Secrets

Before applying the manifests, create the WireGuard secret from your AirVPN WireGuard config file:

```sh
kubectl create secret generic gluetun-airvpn-wireguard \
  --namespace downloads-standard \
  --from-literal=WIREGUARD_PRIVATE_KEY='<PrivateKey from [Interface]>' \
  --from-literal=WIREGUARD_PRESHARED_KEY='<PresharedKey from [Peer]>' \
  --from-literal=WIREGUARD_ADDRESSES='<Address from [Interface], e.g. 10.x.x.x/32,fd7d:76ee:e68f:a993::x/128>'
```
