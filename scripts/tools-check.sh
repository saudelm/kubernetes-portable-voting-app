#!/usr/bin/env bash
set -euo pipefail

required=(docker kubectl helm terraform k3d git python3 ruby node npm)
failures=0

for tool in "${required[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '[ok] %-10s %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '[missing] %s\n' "$tool"
    failures=$((failures + 1))
  fi
done

if command -v gcloud >/dev/null 2>&1; then
  printf '[ok] %-10s %s\n' gcloud "$(command -v gcloud)"
else
  printf '[optional] gcloud is required only for the GKE experiment.\n'
fi

if ! docker info >/dev/null 2>&1; then
  printf '[error] Docker is installed, but its daemon is not reachable.\n'
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  printf 'Tool check failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

printf 'All tools required for the local experiment are ready.\n'
