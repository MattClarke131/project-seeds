# Envoy Gateway

Envoy Gateway is the cluster's ingress controller, replacing the retired ingress-nginx (#444). It turns Gateway API resources into config for Envoy proxy pods.

## Layout
- **`controller/`**: the Helm chart (controller and CRDs), namespace, and the controller's network policy. Flux Kustomization `envoy-gateway`.
- **`gateways/`**: the GatewayClass, both Gateways, their proxy settings (EnvoyProxy), and the proxies' network policies. Flux Kustomization `envoy-gateway-gateways`, which waits for the first so the CRDs exist.
- **`../observability/envoy-gateway/`**: PodMonitors for the controller and proxies.

## The two Gateways
| | `internal` | `public` |
|---|---|---|
| **Who reaches it** | LAN and tailnet clients | Internet visitors, through Pangolin and Newt |
| **Service** | `envoy-internal`, LoadBalancer `10.0.10.62` | `envoy-public`, ClusterIP only |
| **TLS** | Per-hostname certificates, on ListenerSets | None; Pangolin terminates TLS at the edge |
| **Plain HTTP** | Always redirected to HTTPS | Served, since it comes from Newt |
| **Who can attach** | ListenerSets from any namespace | Routes from namespaces labelled `labmatt.com/public-gateway: "true"` |

On `internal`, `traffic-policy-internal.yaml` matches ingress-nginx's behaviour: paths reach apps unchanged (no slash merging or `%2F` decoding), and responses have no total time limit. `public` keeps Envoy's stricter defaults.

The network policies enforce the same split:
- **`envoy-public`** accepts traffic only from Newt and can reach only opted-in namespaces.
- **`envoy-internal`** refuses Newt, so internet traffic can't reach LAN-only apps.

## Exposing an app
**On the LAN**: add a ListenerSet with an HTTPS listener for the app's hostname, plus an HTTPRoute whose `parentRefs` points at that ListenerSet. cert-manager issues the hostname's certificate from the ListenerSet.

**On the internet**:
1. Label the app's namespace `labmatt.com/public-gateway: "true"`.
2. Add an HTTPRoute with `parentRefs: [{name: public, namespace: envoy-gateway-system}]` and the public hostname.
3. Point the app's Pangolin blueprint at `envoy-public.envoy-gateway-system.svc.cluster.local`, port 80.

`services/ladder/` is the reference example for a LAN app.

## Moving a LAN app off ingress-nginx
LAN DNS is a wildcard `*.labmatt.com` record pointing at the control-plane VIP `10.0.10.2`, where ingress-nginx listens on host ports. A record for one hostname overrides the wildcard, so apps move one at a time. Each app takes two PRs:
1. **First PR: routes and DNS.**
   - Add the ListenerSet and HTTPRoute and keep the Ingress. Give the ListenerSet a different Secret name from the Ingress's TLS Secret, so their two Certificates do not collide.
   - Add the hostname to `gateway_hostnames` in `infrastructure/cloudflare/opentofu/variables.tf`.
2. **After merging, test before DNS moves.** `curl --resolve <host>:443:10.0.10.62 https://<host>` should return the app with a valid certificate.
3. **Move DNS.** Run `tofu apply` in `infrastructure/cloudflare/opentofu/` from the main checkout, which holds the state. Check that `dig +short <host> @1.1.1.1` returns `10.0.10.62`.
4. **Second PR: remove the Ingress.** Delete the leftover TLS Secret after merging, since cert-manager keeps it.

## Checking it
```bash
kubectl get gatewayclass,gateway -A          # ACCEPTED/PROGRAMMED should be True
kubectl -n envoy-gateway-system get pods,svc
curl -sI http://10.0.10.62                   # 301 to https://
```
