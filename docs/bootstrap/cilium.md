# Cilium CNI

Run this after the Talos VMs are up and bootstrapped, before anything that needs pod networking (Flux, storage, databases).

The Talos machine config sets `cni: none` and disables kube-proxy, so a fresh cluster has no pod networking until Cilium is installed. Flux cannot install it, because Flux pods need a CNI to start.

A Talos inline manifest will replace this manual step. See [#318](https://github.com/MattClarke131/project-seeds/issues/318).

## Install

1. Confirm the control plane is bootstrapped and the API answers:
   ```bash
   talosctl bootstrap -n 10.0.10.30   # skip if already bootstrapped
   kubectl get nodes                  # nodes show NotReady until Cilium is up
   ```
2. Install Cilium from the same values Flux uses, so Flux adopts the release without drift:
   ```bash
   helm repo add cilium https://helm.cilium.io/
   helm repo update
   helm install cilium cilium/cilium \
     --version "$(yq '.spec.chart.spec.version' infrastructure/kubernetes/cilium/helmrelease.yaml)" \
     --namespace kube-system \
     -f <(yq '.spec.values' infrastructure/kubernetes/cilium/helmrelease.yaml)
   ```
3. Apply the LB pool and L2 policy (Flux applies them later, but ingress needs them now):
   ```bash
   kubectl apply -f infrastructure/kubernetes/cilium/lb-ip-pool.yaml
   kubectl apply -f infrastructure/kubernetes/cilium/l2-announcement-policy.yaml
   ```

## Verify

```bash
kubectl get nodes                                   # all Ready
kubectl get pods -n kube-system -l k8s-app=cilium   # one Running pod per node
kubectl get svc -n ingress-nginx ingress-nginx-controller   # EXTERNAL-IP in 10.0.10.60-69
```

## Notes

- Talos rejects the `SYS_MODULE` capability. The HelmRelease sets explicit capability lists, so do not install with chart defaults.
- Pods created before Cilium (for example from an earlier CNI) keep stale networking. Delete them so they are recreated.
- Flux adopts the release once it reconciles `infrastructure/kubernetes/cilium/`.
