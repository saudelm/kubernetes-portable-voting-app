#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment="${1:-local}"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
output="$root/evidence/${environment}-${timestamp}"

mkdir -p "$output"

kubectl version >"$output/kubectl-version.txt"
kubectl cluster-info >"$output/cluster-info.txt"
kubectl get nodes -o wide >"$output/nodes.txt"
kubectl get all,ingress,networkpolicy,pvc -A -o wide >"$output/workloads.txt"
kubectl get events -A --sort-by=.metadata.creationTimestamp >"$output/events.txt"
helm list -A >"$output/helm-releases.txt"
helm status voting -n voting >"$output/voting-status.txt"

if [[ "$environment" == "local" ]]; then
  curl --fail --show-error --silent http://vote.127.0.0.1.nip.io:8080/ >"$output/vote.html"
  curl --fail --show-error --silent http://result.127.0.0.1.nip.io:8080/ >"$output/result.html"
  terraform -chdir="$root/infra/onprem-k3d" output -json >"$output/terraform-output.json"
else
  terraform -chdir="$root/infra/gke" output -json >"$output/terraform-output.json"
fi

printf 'Evidence written to %s\n' "$output"
