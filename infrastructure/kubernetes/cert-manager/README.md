# cert-manager

Manages TLS certificates for `*.labmatt.com` via Let's Encrypt using Cloudflare DNS-01 challenge.

## Prerequisites

A Cloudflare API token scoped to `labmatt.com` with the following permissions:
- Zone / DNS / Edit
- Zone / Zone / Read

Create one at: Cloudflare Dashboard → My Profile → API Tokens → Create Token

## Installation

`namespace.yaml`, `cluster-issuer.yaml`, and `cert-manager` itself are all
Flux-managed (see below) - the only imperative step left is the secret,
since it's deliberately not tracked in git.

### 1. Create Cloudflare API token secret

The namespace must exist first if this is a fresh cluster (Flux will
create it on first reconcile, or apply `namespace.yaml` by hand to unblock
the secret sooner):

```bash
kubectl create secret generic cloudflare-api-token \
  -n cert-manager \
  --from-literal=api-token=<your-cloudflare-api-token>
```

### 2. cert-manager and the ClusterIssuers

`cert-manager` is Flux-managed (`helmrelease.yaml`, see
[../../../clusters/eye-of-michael/README.md](../../../clusters/eye-of-michael/README.md))
- editing `helmrelease.yaml`'s `spec.values` and merging to `main` is the
deploy step; there's no `helm install`/`helm upgrade` to run by hand any
more. `cluster-issuer.yaml` is Flux-managed the same way.

Two issuers are provided: `letsencrypt-cloudflare` (production) and `letsencrypt-cloudflare-staging` (staging). Use staging when testing to avoid hitting Let's Encrypt rate limits.

Verify both issuers are ready:

```bash
kubectl get clusterissuer
```

## Adding TLS to a service

NGINX ingress reads TLS secrets from the same namespace as the Ingress resource. Add the `cert-manager.io/cluster-issuer` annotation and cert-manager will automatically issue and renew a certificate into the correct namespace:

```yaml
annotations:
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  cert-manager.io/cluster-issuer: letsencrypt-cloudflare
spec:
  tls:
    - hosts:
        - service.labmatt.com
      secretName: <service>-tls
  rules:
    ...
```

cert-manager will create the secret named by `secretName` in the Ingress's namespace and keep it renewed. Each service gets its own secret (e.g. `photos-tls`, `grafana-tls`) so certificates are isolated per service.

Use `letsencrypt-cloudflare-staging` first to confirm the DNS challenge works, then switch the annotation to `letsencrypt-cloudflare` for a trusted certificate. Delete the staging secret before switching so cert-manager issues a fresh one.
