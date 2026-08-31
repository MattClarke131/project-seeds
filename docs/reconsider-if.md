# Reconsider If...

Conditional triggers for decisions made under today's assumptions. Each
entry is a decision that's correct *right now* but depends on something
about the environment staying true - when the condition changes, the
decision should be revisited, not just left on autopilot.

This is a scannable watchlist, not a decision record - see `docs/adr/` for
the full reasoning behind each linked decision.

---

**IF** another *person* gets real Kubernetes-level access to this cluster
(their own `kubectl`/kubeconfig, not just using a hosted app like Jellyfin
or Immich) - a co-maintainer, a friend learning on it -

**THEN** revisit `docs/adr/003-control-plane-metrics-exposure.md`: add
`kube-rbac-proxy` in front of kube-scheduler/kube-controller-manager/
kube-proxy instead of their current open (LAN-reachable) bind-address. That
setup relies on "only I have LAN/cluster access," which stops being true
the moment someone else holds real cluster credentials - at that point
someone other than you could reach those ports directly, no
`hostNetwork` trick even required since they'd already be LAN-reachable.

(This does *not* apply to a GitOps controller getting deployed - see the
next entry. A reconciler with broad standing permissions would likely
already have enough access to authenticate through `kube-rbac-proxy` too,
so it isn't the right mitigation for that case.)

---

**IF** a GitOps controller (FluxCD/ArgoCD, see #15) gets deployed with
broad standing permissions to reconcile this repo onto the cluster -

**THEN** scope its ServiceAccount's RBAC tightly (deny
`hostNetwork`/privileged pod creation at minimum) and add an admission
policy (Kyverno/OPA Gatekeeper) blocking those patterns cluster-wide. This
protects against a compromised git repo/credential becoming automatic
cluster access, which matters regardless of what `docs/adr/
003-control-plane-metrics-exposure.md` decides - it's a different risk than
the one that ADR addresses.
