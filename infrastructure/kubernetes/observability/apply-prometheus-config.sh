#!/usr/bin/env bash

GIT_ROOT=$(git rev-parse --show-toplevel)
TARGETS_DIR="$GIT_ROOT/infrastructure/kubernetes/observability/kube-prometheus-stack"

# Regenerate ConfigMap YAML from JSON
kubectl create configmap prometheus-targets \
  --from-file="$TARGETS_DIR/prometheus-targets.json" \
  --namespace observability \
  --dry-run=client -o yaml > "$TARGETS_DIR/prometheus-targets-configmap.yaml"

# Apply to cluster
kubectl apply -f "$TARGETS_DIR/prometheus-targets-configmap.yaml"

echo "✓ Applied prometheus-targets ConfigMap to observability namespace"
