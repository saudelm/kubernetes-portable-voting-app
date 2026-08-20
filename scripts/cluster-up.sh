#!/usr/bin/env bash
set -euo pipefail

cluster_name="${1:-portable-voting}"

docker info >/dev/null

if k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | awk -v name="$cluster_name" '$0 == name {found = 1} END {exit !found}'; then
  printf "k3d cluster '%s' already exists.\n" "$cluster_name"
else
  k3d cluster create "$cluster_name" \
    --servers 1 \
    --agents 2 \
    --k3s-arg '--disable=traefik@server:*' \
    --port '8080:80@loadbalancer' \
    --port '8443:443@loadbalancer' \
    --wait
fi

kubectl config use-context "k3d-$cluster_name"
kubectl get nodes -o wide
