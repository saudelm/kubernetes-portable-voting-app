#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_name="${1:-portable-voting}"

docker build -t voting-vote:local "$root/vote"
docker build -t voting-result:local "$root/result"
docker build -t voting-worker:local "$root/worker"

if k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | awk -v name="$cluster_name" '$0 == name {found = 1} END {exit !found}'; then
  k3d image import voting-vote:local voting-result:local voting-worker:local --cluster "$cluster_name"
else
  printf "Cluster '%s' does not exist; images were built but not imported.\n" "$cluster_name"
fi
