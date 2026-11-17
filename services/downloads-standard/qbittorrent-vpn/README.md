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

## Metrics

The Torrents Grafana dashboard (Services folder) reads from two sources:

- **qBittorrent** via `../qbittorrent-exporter`, which logs in with cross-seed's `cross-seed-secrets` credentials.
- **gluetun** via json-exporter, which reads the control server on port 8000. `gluetun-control-auth.yaml` opens only `GET /v1/vpn/status` and `GET /v1/publicip/ip`; every other route needs auth.
