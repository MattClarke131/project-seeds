# eye-of-michael — Flux GitOps

Flux manifests for the `eye-of-michael` Kubernetes cluster (see
[`infrastructure/proxmox/opentofu/terraform.tfvars`](../../infrastructure/proxmox/opentofu/terraform.tfvars)
for the cluster name).

See [issue #15](https://github.com/MattClarke131/project-seeds/issues/15)
for the decision (Flux over Argo) and full rollout plan.

## Conventions

`flux-system/` is regenerated, not hand-edited, when Flux itself needs to
change (e.g. adding a component, bumping the Flux version):
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

Per-category `Kustomization` CRs (`observability.yaml`, and more as other
top-level directories get cut over per #15) are the opposite: hand-authored,
not generated, and listed in `flux-system/kustomization.yaml`'s `resources`.
Each points `spec.path` at one top-level manifest directory
(`infrastructure/kubernetes/<category>` or `services/<category>`), which
needs its own `kustomization.yaml` listing the manifests Flux should manage
there - Helm-only subdirectories (still installed by hand, see that
directory's README) and anything not meant to be applied stay out of that
list. Adding a new one needs no imperative step: it's picked up by the next
`flux-system` self-reconcile (≤1m0s) once merged to `main`.

`flux bootstrap github` isn't used: it needs a GitHub token with
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
