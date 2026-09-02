# ADR: Control-Plane Metrics Exposure (kube-scheduler / kube-controller-manager / kube-proxy / etcd)

## Date
2026-08-21 (etcd added 2026-09-01)

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

## Addendum: etcd (2026-09-01)
Same problem, same fix, one more component. Investigating a live Jellyfin
playback stutter traced back to [[project_observability_rollout_safety]]
(issue #125's etcd-overload cascade, recurring for the third time - see
that issue for the incident history) - but with no `etcd_disk_wal_fsync_
duration_seconds` / `etcd_disk_backend_commit_duration_seconds` data
available, there was no way to tell whether the recurring timeouts trace to
actual disk latency or to etcd's own request pattern, only host-level
proxies (disk busy%, CPU steal) that stayed flat through the exact
timeout window.

Talos binds etcd's `--listen-metrics-urls` to loopback by default same as
the other three, for the same reason. Extended `cluster.etcd.extraArgs` in
`infrastructure/proxmox/opentofu/cluster.tf` alongside the existing three:

```yaml
cluster:
  etcd:
    extraArgs:
      listen-metrics-urls: http://0.0.0.0:2381
```

Same risk acceptance as the rest of this ADR: LAN-reachable, unauthenticated,
operational telemetry only (no secrets, no write access - this is
`--listen-metrics-urls`, not `--listen-client-urls`). `docs/reconsider-if.md`'s
existing trigger for this ADR now covers etcd too.

Prometheus scrape config added to `kube-prometheus-stack`'s `helmrelease.yaml`
as a new `etcd` job, reusing the existing `prometheus-targets.json` file_sd
source (filtered to `role: control_plane`, address rewritten to port 2381)
rather than adding a second target file.

**Rollout complete (2026-09-01, same night).** `cluster.tf`'s
`data.talos_machine_configuration` only affects new/recreated VMs, so the
three already-running control-plane nodes each needed a live
`talosctl patch mc` (not `apply-config` - etcd doesn't support a plain
service restart via the Talos API, `rpc error: ... service "etcd" doesn't
support restart operation via API`) followed by a full node reboot to
actually bounce the etcd process and pick up the new arg. Done one node at
a time - `livio-cp` first, then `nicholas-cp`, then `razlo-cp` (the etcd
leader at the time, so its reboot triggered one leader election, expected
and harmless) - verifying quorum (`etcd status`/`etcd members`) and the
metrics port (`curl .../2381/metrics`) after each before moving to the
next. All three confirmed `up` in Prometheus's `etcd` job afterward, with
`etcd_disk_wal_fsync_duration_seconds` actively incrementing on all three.
Quorum stayed healthy throughout (3 members, no missed elections beyond
the one expected one). Jellyfin playback (running on a worker VM, not any
of the rebooted control-plane VMs) was unaffected by any of the three
reboots.
