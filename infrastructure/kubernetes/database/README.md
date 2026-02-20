# CloudNativePG

## Configuration
### Install CloudNativePG Operator
```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm install cnpg cnpg/cloudnative-pg --namespace cnpg-system --create-namespace
```


