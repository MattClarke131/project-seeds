# Renovate

Self-hosted [Renovate](https://docs.renovatebot.com/) instance, run as a Kubernetes
`CronJob` rather than the hosted GitHub App, so nothing external gets installed
on the repo. Scans this repo's `main` branch on a schedule and opens PRs for
outdated container image tags, Helm chart versions, Terraform provider
versions, and `hermes`'s npm dependencies.

Repo-level behavior (grouping, scheduling, dashboard) is configured in
[`renovate.json`](../../../../renovate.json) at the repo root - that's what
Renovate reads once it clones the repo. This directory only holds the
cluster-side pieces that run the bot itself.

## Layout
- `../namespace.yaml` - the `ci-cd` namespace (`restricted` pod security -
  Renovate doesn't need host access, unlike most other namespaces in this repo)
- `cronjob.yaml` - runs `renovate/renovate` daily at 6 AM against
  `MattClarke131/project-seeds`

## Apply

This namespace and the CronJob are Flux-managed (see
[../../../../clusters/eye-of-michael/README.md](../../../../clusters/eye-of-michael/README.md))
- editing `cronjob.yaml` and merging to `main` is the deploy step; there's
no `kubectl apply` to run by hand any more.

## GitHub token

The CronJob reads a GitHub token from a Secret it does not create itself -
create it manually, it's never committed to git:

```
kubectl create secret generic renovate-github-token \
  --from-literal=token=<PAT> \
  -n ci-cd
```

The PAT should be a **fine-grained** personal access token (not classic -
those can't be scoped to a single repo), restricted to this repository only,
with:
- Contents: Read and write
- Pull requests: Read and write
- Issues: Read and write (Dependency Dashboard)
- Workflows: Read and write
- Metadata: Read-only (included automatically)

Fine-grained tokens expire (1 year max) - this one will need to be rotated
before it does, or the CronJob starts failing silently. When rotating,
generate the replacement first, then update the secret in place:

```
kubectl create secret generic renovate-github-token \
  --from-literal=token=<NEW_PAT> \
  -n ci-cd \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Schedule

Currently daily (`0 6 * * *`) to surface the initial backlog and get a feel
for PR volume. Worth tightening to weekly once that settles - see
`cronjob.yaml`.
