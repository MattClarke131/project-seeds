# Installation
Reflector runs in kube-system as it is cluster-wide infrastructure.
```bash
helm repo add emberstack https://emberstack.github.io/helm-charts
helm repo update
helm install reflector emberstack/reflector --namespace kube-system
```
