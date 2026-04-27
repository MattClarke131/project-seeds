# cert-manager

Manages TLS certificates for `*.labmatt.com` via Let's Encrypt using Cloudflare DNS-01 challenge.

## Prerequisites

A Cloudflare API token scoped to `labmatt.com` with the following permissions:
- Zone / DNS / Edit
- Zone / Zone / Read

Create one at: Cloudflare Dashboard → My Profile → API Tokens → Create Token

## Installation

### 1. Create namespace

```bash
kubectl apply -f infrastructure/kubernetes/cert-manager/namespace.yaml
```

### 2. Create Cloudflare API token secret

This secret is not tracked in git and must be created imperatively:

```bash
kubectl create secret generic cloudflare-api-token \
  -n cert-manager \
  --from-literal=api-token=<your-cloudflare-api-token>
```

### 3. Install cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  -n cert-manager \
  -f infrastructure/kubernetes/cert-manager/values.yaml
```

### 4. Apply ClusterIssuers

Two issuers are provided: `letsencrypt-cloudflare` (production) and `letsencrypt-cloudflare-staging` (staging). Use staging when testing to avoid hitting Let's Encrypt rate limits.

```bash
kubectl apply -f infrastructure/kubernetes/cert-manager/cluster-issuer.yaml
```

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
