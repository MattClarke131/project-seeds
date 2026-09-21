# vpn-egress

Shared gluetun (AirVPN, WireGuard) pod exposing an HTTP proxy so other
workloads can egress from a VPN IP without their own gluetun sidecar.

- Proxy URL (in-cluster): `http://vpn-egress.vpn-egress.svc.cluster.local:8888`
- autobrr: Settings > IRC > network > Proxy, type HTTP, URL above.
- Allowed clients: `networkpolicy.yaml` denies all ingress. Add a rule per client before enforcement is enabled.

## Secret

Generate a new WireGuard device in AirVPN (one connection per device; do not
reuse another pod's keys), then:

```sh
kubectl create secret generic vpn-egress-airvpn-wireguard \
  --namespace vpn-egress \
  --from-literal=WIREGUARD_PRIVATE_KEY='<PrivateKey from [Interface]>' \
  --from-literal=WIREGUARD_PRESHARED_KEY='<PresharedKey from [Peer]>' \
  --from-literal=WIREGUARD_ADDRESSES='<Address from [Interface]>'
```

## Check

```sh
kubectl run -n downloads-standard curltest --rm -it --restart=Never --image=curlimages/curl -- \
  curl -sx http://vpn-egress.vpn-egress.svc.cluster.local:8888 https://ifconfig.me
```

The IP must differ from the cluster's direct egress IP. AirVPN allows 5
simultaneous connections per account.
