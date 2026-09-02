#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_context="${1:-k3d-portable-voting}"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
output="$root/evidence/local-$timestamp"
summary="$output/test-summary.txt"

mkdir -p "$output"

current_context="$(kubectl config current-context)"
if [[ "$current_context" != "$expected_context" ]]; then
  printf 'Expected kubectl context %s, got %s.\n' "$expected_context" "$current_context" >&2
  exit 1
fi

pass() {
  printf 'PASS | %s\n' "$1" | tee -a "$summary"
}

fail() {
  printf 'FAIL | %s\n' "$1" | tee -a "$summary" >&2
  exit 1
}

db_tally() {
  kubectl exec -n voting voting-voting-app-postgres-0 -- \
    psql -U postgres -d postgres -Atc \
    "SELECT vote, count(*) FROM votes GROUP BY vote ORDER BY vote"
}

printf 'Local Kubernetes evidence run\n' >"$summary"
printf 'Started UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" | tee -a "$summary"
printf 'Started local: %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" | tee -a "$summary"
printf 'Kubectl context: %s\n' "$current_context" | tee -a "$summary"
git -C "$root" rev-parse HEAD >"$output/git-commit.txt"
docker version >"$output/docker-version.txt"
k3d version >"$output/k3d-version.txt"
kubectl version >"$output/kubectl-version.txt"
helm version >"$output/helm-version.txt"
terraform version >"$output/terraform-version.txt"
kubectl cluster-info >"$output/cluster-info.txt"
kubectl get nodes -o wide >"$output/nodes.txt"
kubectl get all,ingress,networkpolicy,pvc -A -o wide >"$output/workloads-before-tests.txt"
helm list -A >"$output/helm-releases.txt"
helm status voting -n voting >"$output/voting-status.txt"
terraform -chdir="$root/infra/onprem-k3d" output -json >"$output/terraform-output.json"

printf '\nT1 - fachlicher Durchstich\n' | tee -a "$summary"
curl --fail --show-error --silent \
  http://vote.127.0.0.1.nip.io:8080/healthz >"$output/t1-vote-health.txt"
curl --fail --show-error --silent \
  http://result.127.0.0.1.nip.io:8080/healthz >"$output/t1-result-health.txt"

before_total="$(db_tally | awk -F '|' '{sum += $2} END {print sum + 0}')"
printf '%s\n' "$before_total" >"$output/t1-total-before.txt"
curl --fail --show-error --silent \
  --cookie-jar "$output/t1-cookies.txt" \
  --data 'vote=a' \
  http://vote.127.0.0.1.nip.io:8080/ >"$output/t1-vote-response.html"

after_total="$before_total"
for _ in $(seq 1 30); do
  after_total="$(db_tally | awk -F '|' '{sum += $2} END {print sum + 0}')"
  if (( after_total > before_total )); then
    break
  fi
  sleep 1
done

db_tally >"$output/t1-database-tally.txt"
printf '%s\n' "$after_total" >"$output/t1-total-after.txt"
curl --fail --show-error --silent \
  http://result.127.0.0.1.nip.io:8080/ >"$output/t1-result-response.html"

if [[ "$(<"$output/t1-vote-health.txt")" != "ok" ]]; then
  fail 'T1 Vote-Health-Endpunkt antwortet nicht mit ok'
fi
if [[ "$(<"$output/t1-result-health.txt")" != "ok" ]]; then
  fail 'T1 Result-Health-Endpunkt antwortet nicht mit ok'
fi
if (( after_total <= before_total )); then
  fail 'T1 abgegebene Stimme wurde nicht in PostgreSQL gespeichert'
fi
pass "T1 Health-Endpunkte und Stimmenfluss (Datensaetze $before_total -> $after_total)"

printf '\nT2 - Persistenz nach PostgreSQL-Pod-Ersatz\n' | tee -a "$summary"
db_tally >"$output/t2-before.txt"
kubectl delete pod -n voting voting-voting-app-postgres-0 >"$output/t2-delete.txt"
kubectl wait -n voting --for=condition=Ready \
  pod/voting-voting-app-postgres-0 --timeout=300s >"$output/t2-wait.txt"
db_tally >"$output/t2-after.txt"
if diff -u "$output/t2-before.txt" "$output/t2-after.txt" >"$output/t2-diff.txt"; then
  pass 'T2 Datenbestand nach PostgreSQL-Pod-Ersatz unveraendert'
else
  fail 'T2 Datenbestand hat sich nach PostgreSQL-Pod-Ersatz veraendert'
fi

printf '\nT3 - Selbstheilung des Vote-Deployments\n' | tee -a "$summary"
kubectl get pods -n voting -l app.kubernetes.io/component=vote \
  -o custom-columns=NAME:.metadata.name,UID:.metadata.uid \
  >"$output/t3-before.txt"
before_uids="$(kubectl get pods -n voting -l app.kubernetes.io/component=vote \
  -o jsonpath='{range .items[*]}{.metadata.uid}{"\\n"}{end}' | sort)"
kubectl delete pod -n voting -l app.kubernetes.io/component=vote >"$output/t3-delete.txt"
kubectl rollout status -n voting deployment/voting-voting-app-vote \
  --timeout=300s >"$output/t3-rollout.txt"
kubectl wait -n voting --for=condition=Ready pod \
  -l app.kubernetes.io/component=vote --timeout=300s >"$output/t3-wait.txt"
kubectl get pods -n voting -l app.kubernetes.io/component=vote \
  -o custom-columns=NAME:.metadata.name,UID:.metadata.uid \
  >"$output/t3-after.txt"
after_uids="$(kubectl get pods -n voting -l app.kubernetes.io/component=vote \
  -o jsonpath='{range .items[*]}{.metadata.uid}{"\\n"}{end}' | sort)"
if [[ -z "$before_uids" || -z "$after_uids" || "$before_uids" == "$after_uids" ]]; then
  fail 'T3 Vote-Pod wurde nicht mit neuer UID wiederhergestellt'
fi
pass 'T3 Vote-Pod automatisch mit neuer UID wiederhergestellt'

printf '\nT4 - NetworkPolicy\n' | tee -a "$summary"
kubectl exec -n voting deploy/voting-voting-app-vote -- python -c \
  'import socket; s=socket.create_connection(("voting-voting-app-redis",6379),3); print("redis reachable"); s.close()' \
  >"$output/t4-redis-allowed.txt" 2>&1
pass 'T4 erlaubter Vote-zu-Redis-Verbindungsweg erreichbar'

if kubectl exec -n voting deploy/voting-voting-app-vote -- python -c \
  'import socket; socket.create_connection(("voting-voting-app-postgres",5432),3)' \
  >"$output/t4-postgres-blocked.txt" 2>&1; then
  fail 'T4 unerlaubter Vote-zu-PostgreSQL-Verbindungsweg war erreichbar'
else
  printf 'Expected connection failure; NetworkPolicy blocked the path.\n' \
    >>"$output/t4-postgres-blocked.txt"
  pass 'T4 unerlaubter Vote-zu-PostgreSQL-Verbindungsweg blockiert'
fi

curl --fail --show-error --silent \
  http://grafana.127.0.0.1.nip.io:8080/api/health >"$output/grafana-health.json"
pass 'Grafana-Health-Endpunkt erreichbar'

kubectl get all,ingress,networkpolicy,pvc -A -o wide >"$output/workloads-after-tests.txt"
kubectl get events -A --sort-by=.metadata.creationTimestamp >"$output/events.txt"
kubectl get pods -n voting -o wide >"$output/voting-pods-final.txt"
printf 'Finished UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" | tee -a "$summary"
printf 'Evidence directory: %s\n' "$output" | tee -a "$summary"
printf '%s\n' "$output"
