# eye-of-michael — Flux GitOps

Flux manifests for the `eye-of-michael` Kubernetes cluster (see
[`infrastructure/proxmox/opentofu/terraform.tfvars`](../../infrastructure/proxmox/opentofu/terraform.tfvars)
for the cluster name).

See [issue #15](https://github.com/MattClarke131/project-seeds/issues/15)
for the decision (Flux over Argo) and full rollout plan.

## What's here right now

Just the bootstrap: `flux-system/` installs Flux's controllers
(source-controller, kustomize-controller, helm-controller,
notification-controller) and points them at this repo, so Flux can manage
its own manifests going forward. Nothing else is Flux-managed yet -
`kubectl apply` / `helm install` remain the deploy mechanism for every
existing workload under `infrastructure/kubernetes/` and `services/`. Real
categories (starting with `observability`) get their own `Kustomization`
here in a follow-up.

`flux-system/` was generated with:
```bash
flux install --export > flux-system/gotk-components.yaml

flux create source git flux-system \
  --url=https://github.com/MattClarke131/project-seeds \
  --branch=main \
  --export > /tmp/gotk-source.yaml

flux create kustomization flux-system \
  --source=GitRepository/flux-system \
  --path=./clusters/eye-of-michael/flux-system \
  --prune=true \
  --export > /tmp/gotk-kustomization.yaml

cat /tmp/gotk-source.yaml /tmp/gotk-kustomization.yaml > flux-system/gotk-sync.yaml
```

`flux bootstrap github` wasn't used: it needs a GitHub token with
deploy-key/admin permissions to auto-provision a deploy key, which the
token available here doesn't have. It's also unneeded - the repo is
public, so Flux's `GitRepository` pulls over anonymous HTTPS with no
credentials at all. Generating the manifests with `--export` instead keeps
this on a normal PR rather than `flux bootstrap`'s direct-push-to-main
behavior.

## Installing (one-time)

Merging a PR that touches this directory does **not** install anything by
itself - it's just git state until something applies it. After merging:

```bash
kubectl apply -k clusters/eye-of-michael/flux-system
```

This is the one-time imperative bootstrap step (same category as the
manual `helm install` steps documented in
[`infrastructure/kubernetes/README.md`](../../infrastructure/kubernetes/README.md)).
After it runs, Flux is live and immediately starts reconciling itself from
git via the self-referential `Kustomization` in `gotk-sync.yaml` - any
future change to `flux-system/gotk-components.yaml` (e.g. a Flux version
bump) lands automatically without needing this command again.

Verify:
```bash
flux check
flux get all -A
kubectl get pods -n flux-system
```
