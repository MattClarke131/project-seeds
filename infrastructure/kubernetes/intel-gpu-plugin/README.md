# intel-gpu-plugin

Registers `/dev/dri` with kubelet's Device Plugin API as an allocatable `gpu.intel.com/i915`
resource, so pods can request the GPU properly instead of a raw `hostPath` mount (which
never grants the pod's cgroup actual device access - a plain `hostPath` mount looks fine
via file permissions but still fails with "Operation not permitted" when opened).

## Prerequisites

The node needs the `i915` kernel driver already loaded and the GPU passed through - see
[`../../../docs/bootstrap/talos.md`](../../../docs/bootstrap/talos.md). This plugin only
discovers and registers devices that already exist; it doesn't install drivers.

## Installation

```bash
kubectl apply -f infrastructure/kubernetes/intel-gpu-plugin/daemonset.yaml
```

No namespace or RBAC to create separately - see the comments in `daemonset.yaml` for why.

## Verification

```bash
kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{" i915: "}{.status.allocatable.gpu\.intel\.com/i915}{"\n"}{end}'
```

`k8s-livio-w1` should show `1`; every other node should show nothing (the DaemonSet
doesn't run there).

## Consuming the GPU

Request it as a resource instead of mounting `/dev/dri` directly:

```yaml
resources:
  limits:
    gpu.intel.com/i915: 1
```

See `services/jellyfin/values.yaml` for the real usage.
