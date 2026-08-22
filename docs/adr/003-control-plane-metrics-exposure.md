# ADR: Control-Plane Metrics Exposure (kube-scheduler / kube-controller-manager / kube-proxy)

## Date
2026-08-21

## Status
Accepted

## Context
kube-prometheus-stack's default alert rules expect to scrape kube-scheduler,
kube-controller-manager, and kube-proxy directly, but on Talos all three are
hardcoded to bind their metrics port to `127.0.0.1` (confirmed by
inspecting their live container commands) - reachable only from other
processes sharing that exact node's network namespace, not from Prometheus
running elsewhere in the cluster. This produces persistent `TargetDown`
alerts for all three that were never going to resolve on their own; it's a
deliberate Talos security default, not an outage.

This matters beyond just clearing noisy alerts: these three components are
genuinely important. A scheduler failure means no new pods get scheduled
cluster-wide; a controller-manager failure means node/pod lifecycle
reconciliation stalls; a kube-proxy failure on a node breaks that node's
Service networking. Muting the alerts outright would trade away real
visibility into a real failure mode for nothing - the alert only looks
useless today because it's stuck on an unrelated scrape problem, not
because the underlying health check has no value.

## Decision
### Flip bind-address to 0.0.0.0 via Talos machine config
Add `extraArgs` to `cluster.scheduler`, `cluster.controllerManager`, and
`cluster.proxy` in Talos machine config, applied via `talosctl
apply-config` across all 3 control-plane nodes:

```yaml
cluster:
  controllerManager:
    extraArgs:
      bind-address: 0.0.0.0
  scheduler:
    extraArgs:
      bind-address: 0.0.0.0
  proxy:
    extraArgs:
      metrics-bind-address: 0.0.0.0:10249
```

This is also the documented, common fix other Talos users apply for this
exact problem (see e.g. [siderolabs/talos discussion
#7799](https://github.com/siderolabs/talos/discussions/7799)) - not a
bespoke workaround.

**Risk accepted**: this makes each component's metrics/healthz endpoint
reachable by anything on the LAN (`10.0.10.0/24`), not just Prometheus. No
credentials, tokens, or secrets are exposed - only operational telemetry
(scheduling/reconciliation internals, exact component versions). This
requires an attacker who already has a foothold on the LAN to have any
value at all, and even then it's reconnaissance-grade information, not a
path to access. Nothing here is internet-reachable either way.

## Alternatives Considered

### Unauthenticated relay/forwarder sidecar per control-plane node
Initially planned: keep the components bound to loopback, and add a small
`hostNetwork: true` DaemonSet that relays traffic from a new, LAN-reachable
port to the real loopback-bound port on the same node.

Rejected on reassessment: this is **security-equivalent** to the direct
bind-address flip, not a meaningfully safer middle ground. The relay adds
no authentication - it's a dumb byte-forwarder - so the same data ends up
reachable to the same LAN audience either way; the only real difference is
that the actual component's own bind-address stays untouched (Talos's
config for it is unmodified) while a separate process is exposed instead.
That's a real but much smaller distinction ("don't touch Talos's own
component config") than "more secure," and didn't justify a new DaemonSet,
Service, and ServiceMonitor for an identical security outcome.

### `kube-rbac-proxy` (the kubeadm-standard pattern)
The pattern real production kubeadm clusters use for this exact problem -
RBAC/token-authenticated access instead of an open endpoint. Rejected for
now, but not on resource-cost grounds - the extra footprint (TLS certs,
ClusterRole for TokenReview, several more container instances) is trivial
on this cluster's actual capacity and isn't a real constraint. The reasons
that actually matter:
- More moving parts that can silently break later (certs, RBAC bindings,
  bearer-token config in Prometheus), independent of what they cost to run
- The risk this pattern protects against - another party with `kubectl`
  access deploying a `hostNetwork` pod to reach these ports directly -
  doesn't apply today (single operator, no other cluster users)
- It's not what the Talos community actually does for this specific
  problem; the documented fixes go straight to the bind-address flip

See `docs/reconsider-if.md` for the condition that would change this
conclusion.

### Mute the alerts, no fix
Rejected - these three components are important enough that losing real
visibility into their health isn't worth avoiding a cheap, well-precedented
fix. See Context above.
