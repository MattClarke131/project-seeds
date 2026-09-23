# vpn-egress

Shared gluetun (AirVPN, WireGuard) pod exposing an HTTP proxy so other
workloads can egress from a VPN IP without their own gluetun sidecar.

- Proxy URL (in-cluster): `http://vpn-egress.vpn-egress.svc.cluster.local:8888`
- autobrr: Settings > IRC > network > Proxy, type HTTP, URL above.
- Allowed clients: `networkpolicy.yaml` denies all ingress. Add a rule per client before enforcement is enabled.

## Secret

This pod cannibalizes ZNC's AirVPN device (`znc-vpn/znc-vpn-airvpn-wireguard`),
which is idle - ZNC's gluetun Deployment is scaled to 0 - instead of creating
a new one, so it doesn't consume another of AirVPN's 5 connection slots.
Rename the device `gluetun-egress` in the AirVPN dashboard, then copy the
secret into this namespace:

```sh
kubectl get secret znc-vpn-airvpn-wireguard -n znc-vpn -o json \
  | jq '.metadata = {name:"vpn-egress-airvpn-wireguard", namespace:"vpn-egress"}' \
  | kubectl apply -f -
```

Once vpn-egress is confirmed working, retire ZNC's gluetun sidecar: delete
its Deployment, Service and the `znc-vpn-airvpn-wireguard` secret (leave the
`znc-vpn-config` PVC - that's app data, unrelated to the VPN key).

## Check

```sh
kubectl run -n downloads-standard curltest --rm -it --restart=Never --image=curlimages/curl -- \
  curl -sx http://vpn-egress.vpn-egress.svc.cluster.local:8888 https://ifconfig.me
```

The IP must differ from the cluster's direct egress IP. AirVPN allows 5
simultaneous connections per account.
