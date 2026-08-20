#!/usr/bin/env bash
set -euo pipefail

for tool in gcloud gh kubectl; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'Fehlendes Werkzeug: %s\n' "$tool" >&2
    exit 1
  }
done

: "${PROJECT_ID:?PROJECT_ID fehlt}"
: "${GKE_LOCATION:?GKE_LOCATION fehlt}"
: "${CLUSTER_NAME:?CLUSTER_NAME fehlt}"
: "${NAMESPACE:?NAMESPACE fehlt}"
: "${GHCR_USERNAME:?GHCR_USERNAME fehlt}"
: "${SECRET_NAME:?SECRET_NAME fehlt}"

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --location "$GKE_LOCATION" \
  --project "$PROJECT_ID" >/dev/null

token="${GHCR_TOKEN:-}"
if [[ -z "$token" ]]; then
  token="$(gh auth token)"
fi

if [[ -z "$token" ]]; then
  printf 'Kein GHCR-Lesetoken verfuegbar.\n' >&2
  exit 1
fi

trap 'unset token' EXIT

kubectl create secret docker-registry "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --docker-server ghcr.io \
  --docker-username "$GHCR_USERNAME" \
  --docker-password "$token" \
  --dry-run=client \
  -o yaml | kubectl apply -f - >/dev/null

printf 'Privater GHCR-Lesezugriff wurde im Namespace %s eingerichtet.\n' "$NAMESPACE"
