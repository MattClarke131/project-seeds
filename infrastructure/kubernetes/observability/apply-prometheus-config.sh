#!/usr/bin/env bash

GIT_ROOT=$(git rev-parse --show-toplevel)
TARGETS_DIR="$GIT_ROOT/infrastructure/kubernetes/observability/kube-prometheus-stack"

# Regenerate ConfigMap YAML from JSON
kubectl create configmap prometheus-targets \
  --from-file="$TARGETS_DIR/prometheus-targets.json" \
  --namespace observability \
  --dry-run=client -o yaml > "$TARGETS_DIR/prometheus-targets-configmap.yaml"

# Flux applies this once it's committed and merged (kustomization.yaml
# lists it as a managed resource) - no live kubectl apply here any more.
echo "✓ Regenerated prometheus-targets-configmap.yaml - commit and merge to deploy"
