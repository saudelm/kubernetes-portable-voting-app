#!/usr/bin/env bash
set -euo pipefail

for namespace in traefik voting monitoring; do
  if kubectl get namespace "$namespace" >/dev/null 2>&1; then
    printf '\n[%s]\n' "$namespace"
    kubectl get pods -n "$namespace" -o wide
  fi
done
