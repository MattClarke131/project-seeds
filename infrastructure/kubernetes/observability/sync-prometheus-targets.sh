#!/usr/bin/env bash

GIT_ROOT=$(git rev-parse --show-toplevel)

cd "$GIT_ROOT/infrastructure/proxmox/opentofu"
tofu output -json prometheus_scrape_targets \
  > "$GIT_ROOT/infrastructure/kubernetes/observability/kube-prometheus-stack/prometheus-targets.json"
