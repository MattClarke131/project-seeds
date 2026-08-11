# Installation
Reflector runs in kube-system as it is cluster-wide infrastructure.
```bash
helm repo add emberstack https://emberstack.github.io/helm-charts
helm repo update
helm install reflector emberstack/reflector --namespace kube-system
```

# Adding a consumer namespace

Apps that connect to the shared Postgres cluster (e.g. `*arr` apps in
`downloads-standard`) need three things applied in this order:

1. Add the namespace to `reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces`
   on the `Cluster` in `infrastructure/kubernetes/database/postgres-cluster.yaml`.
2. Apply the app's `postgresql.cnpg.io/v1` `Database` CRs (in the app's own
   service directory) to create its databases on the cluster.
3. Apply a `Secret` in the consuming namespace with
   `reflector.v1.k8s.emberstack.com/reflects: "database/postgres-app"` so
   Reflector mirrors the connection credentials in.

Only after all three exist will an app's `Deployment` (and any initContainer
that reads `postgres-secret`, e.g. radarr's config.xml patcher) actually start
cleanly — applying the Deployment first just leaves it blocked in
`CreateContainerConfigError` until the secret shows up.
