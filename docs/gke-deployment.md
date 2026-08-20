# GKE-Durchfuehrung und Nachweisplan

Diese Anleitung ist fuer die spaetere, reale Durchfuehrung des Cloud-Teils bestimmt. Erst die dabei erzeugten Ausgaben und Screenshots duerfen in Kapitel 6 als empirische Ergebnisse bezeichnet werden. Die statische Manifestanalyse allein beweist keine erfolgreiche GKE-Bereitstellung.

## 1. Kosten und Sicherheit vor dem Start

GKE-Cluster, Compute-Instanzen, Load Balancer, Persistent Disk und gegebenenfalls die reservierte IP koennen Kosten verursachen. Preise und moegliche Freikontingente koennen sich aendern. Vor dem Start pruefen:

- [GKE-Preise](https://cloud.google.com/kubernetes-engine/pricing)
- [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator)
- [Budgets und Benachrichtigungen](https://cloud.google.com/billing/docs/how-to/budgets)

Budgetbenachrichtigungen sind keine automatische Ausgabensperre. Die Umgebung direkt nach dem Versuch mit `terraform destroy` abbauen und den Abbau kontrollieren.

Keine Kennwoerter, Service-Account-Schluessel, Terraform-States oder `tfplan`-Dateien committen. Das Projekt-`.gitignore` schliesst diese Dateien aus.

## 2. Voraussetzungen

1. Eigenes Google-Cloud-Projekt mit aktivierter Abrechnung und ausreichenden Rechten fuer Service Usage, Compute Engine und GKE.
2. Installierte Werkzeuge: `gcloud`, `terraform >= 1.6`, `kubectl`, `helm`, `git`, `curl` und `openssl`. Der dokumentierte CI-Stand verwendet Terraform 1.15.8 und Helm 4.2.3.
3. Drei ueber GitHub Actions gebaute GHCR-Images mit demselben Commit-SHA-Tag.
4. GHCR-Pakete sind fuer das Experiment oeffentlich. Alternativ muss vorab ein `imagePullSecret` konzipiert und in den Values referenziert werden.
5. Genuegend regionale Quote fuer zwei `e2-standard-2`-Knoten und eine externe Load-Balancer-IP.

Offizielle Installationsanleitung fuer die CLI: [Google Cloud CLI installieren](https://cloud.google.com/sdk/docs/install).

## 3. Projekt- und Imagewerte festlegen

Im Projektstamm ein Terminal oeffnen und Werte setzen:

```bash
export PROJECT_ID="DEIN-EINDEUTIGES-PROJEKT"
export GKE_LOCATION="europe-west3-a"
export IMAGE_TAG="VOLLSTAENDIGER_GITHUB_COMMIT_SHA"
export TF_VAR_image_repository_base="ghcr.io/DEIN-GITHUB-NAME/DEIN-REPOSITORY"
export TF_VAR_postgres_password="$(openssl rand -base64 24)"
export TF_VAR_grafana_admin_password="$(openssl rand -base64 24)"
```

Der Image-Tag muss 7 bis 40 hexadezimale Zeichen enthalten. Fuer den eigentlichen Versuch den vollstaendigen 40-stelligen SHA aus dem erfolgreichen CI-Lauf verwenden. `TF_VAR_image_repository_base` muss exakt auf das eigene GHCR-Repository ohne abschliessenden Schraegstrich zeigen; Terraform leitet daraus die drei Komponentenpfade ab.

Optional die Existenz der Images pruefen:

```bash
docker manifest inspect "${TF_VAR_image_repository_base}/vote:${IMAGE_TAG}" >/dev/null
docker manifest inspect "${TF_VAR_image_repository_base}/result:${IMAGE_TAG}" >/dev/null
docker manifest inspect "${TF_VAR_image_repository_base}/worker:${IMAGE_TAG}" >/dev/null
```

## 4. Bei Google Cloud anmelden

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project "$PROJECT_ID"
gcloud auth application-default set-quota-project "$PROJECT_ID"
gcloud projects describe "$PROJECT_ID"
```

Terraform aktiviert `compute.googleapis.com` und `container.googleapis.com`. Fehlen dafuer Rechte oder ist keine Abrechnung verknuepft, bricht der Plan kontrolliert ab.

## 5. Vorpruefung und statischer Vergleich

```bash
helm lint charts/voting-app
ruby scripts/compare-portability.rb
terraform -chdir=infra/gke fmt -check
terraform -chdir=infra/gke init
terraform -chdir=infra/gke validate
```

Erwartung fuer den dokumentierten Stand: 35 gemeinsame Objektidentitaeten und keine unerwartete Manifestabweichung. Eine andere Zahl muss vor dem Cloud-Lauf untersucht und in der Arbeit erklaert werden.

## 6. Plan erstellen und pruefen

```bash
terraform -chdir=infra/gke plan \
  -out=tfplan \
  -var "project_id=${PROJECT_ID}" \
  -var "location=${GKE_LOCATION}" \
  -var "image_tag=${IMAGE_TAG}"
```

Vor dem Apply kontrollieren:

- ein zonaler Cluster `portable-voting`,
- ein Node Pool mit zwei Knoten,
- eine regionale statische IP,
- Namespaces `traefik`, `voting` und `monitoring`,
- Traefik, Voting-App, Prometheus und Grafana als Helm-Releases.

Keine Ressourcenzahl vorab in die Arbeit uebernehmen; sie kann sich durch Provider- und Chartversionen aendern.

## 7. Einmalige Bereitstellung

Startzeit notieren und den geprueften Plan anwenden:

```bash
date -Iseconds
terraform -chdir=infra/gke apply tfplan
date -Iseconds
```

Terraform reserviert die externe IP vorab, weist sie Traefik zu und erzeugt daraus die drei nip.io-Hosts. Deshalb ist kein manueller zweiter Apply zur Ersetzung eines `<LB_IP>`-Platzhalters vorgesehen.

Folgende Werte sichern, ohne Kennwoerter abzubilden:

```bash
terraform -chdir=infra/gke output
terraform -chdir=infra/gke output -json > evidence/gke-terraform-output.json
```

## 8. kubectl verbinden und Sollzustand pruefen

```bash
gcloud container clusters get-credentials portable-voting \
  --location "$GKE_LOCATION" \
  --project "$PROJECT_ID"

kubectl get nodes -o wide
kubectl get pods -n traefik -o wide
kubectl get pods -n voting -o wide
kubectl get pods -n monitoring -o wide
kubectl get ingress -A
kubectl get networkpolicy -n voting
kubectl get pvc -n voting
kubectl get svc -n traefik traefik
```

Erwartung im Namespace `voting`: zwei Vote-Pods, zwei Result-Pods, je ein Worker- und Redis-Pod sowie `postgres-0`, insgesamt sieben laufende Pods. Die externe Service-IP muss dem Terraform-Output `ingress_ip` entsprechen.

URLs anzeigen:

```bash
terraform -chdir=infra/gke output -raw vote_url
terraform -chdir=infra/gke output -raw result_url
terraform -chdir=infra/gke output -raw grafana_url
```

## 9. T1 - fachlicher Durchstich

1. Vote-URL im Browser mit sichtbarer Adresszeile oeffnen.
2. Eine Stimme abgeben.
3. Result-URL oeffnen und pruefen, ob die Stimme angezeigt wird.
4. Beide Ansichten als eigene Screenshots speichern.

Zusaetzliche technische Pruefung:

```bash
VOTE_URL="$(terraform -chdir=infra/gke output -raw vote_url)"
RESULT_URL="$(terraform -chdir=infra/gke output -raw result_url)"
curl --fail --show-error "${VOTE_URL}/healthz"
curl --fail --show-error "${RESULT_URL}/healthz"
```

Erfolg: Beide Health-Endpunkte antworten erfolgreich und die abgegebene Stimme erscheint in Result.

## 10. T2 - Persistenz nach Pod-Ersatz

Nach mindestens einer abgegebenen Stimme Tabelleninhalt sichern:

```bash
mkdir -p evidence/manual-gke
kubectl exec -n voting voting-voting-app-postgres-0 -- \
  psql -U postgres -d postgres -Atc \
  "SELECT vote, count(*) FROM votes GROUP BY vote ORDER BY vote" \
  > evidence/manual-gke/t2-before.txt

kubectl delete pod -n voting voting-voting-app-postgres-0
kubectl wait -n voting --for=condition=Ready \
  pod/voting-voting-app-postgres-0 --timeout=300s

kubectl exec -n voting voting-voting-app-postgres-0 -- \
  psql -U postgres -d postgres -Atc \
  "SELECT vote, count(*) FROM votes GROUP BY vote ORDER BY vote" \
  > evidence/manual-gke/t2-after.txt

diff -u evidence/manual-gke/t2-before.txt evidence/manual-gke/t2-after.txt
```

Erfolg: `diff` gibt keinen Unterschied aus und Result zeigt weiterhin denselben Stand. Das prueft Pod-Ersatz mit bestehendem Volume, nicht Backup oder clusteruebergreifende Datenmigration.

## 11. T3 - Selbstheilung

```bash
kubectl get pods -n voting -l app.kubernetes.io/component=vote \
  -o custom-columns=NAME:.metadata.name,UID:.metadata.uid \
  > evidence/manual-gke/t3-before.txt

kubectl delete pod -n voting -l app.kubernetes.io/component=vote
kubectl rollout status -n voting deployment/voting-voting-app-vote --timeout=300s
kubectl wait -n voting --for=condition=Ready pod \
  -l app.kubernetes.io/component=vote --timeout=300s

kubectl get pods -n voting -l app.kubernetes.io/component=vote \
  -o custom-columns=NAME:.metadata.name,UID:.metadata.uid \
  > evidence/manual-gke/t3-after.txt

cat evidence/manual-gke/t3-before.txt
cat evidence/manual-gke/t3-after.txt
```

Erfolg: Zwei neue Vote-Pod-UIDs sind vorhanden und beide Pods sind Ready.

## 12. T4 - NetworkPolicy

Erlaubten Weg Vote zu Redis testen:

```bash
kubectl exec -n voting deploy/voting-voting-app-vote -- python -c \
  'import socket; s=socket.create_connection(("voting-voting-app-redis",6379),3); print("redis reachable"); s.close()'
```

Nicht erlaubten Weg Vote zu PostgreSQL testen:

```bash
if kubectl exec -n voting deploy/voting-voting-app-vote -- python -c \
  'import socket; socket.create_connection(("voting-voting-app-postgres",5432),3)'; then
  echo "FEHLER: PostgreSQL war vom Vote-Pod erreichbar"
else
  echo "ERWARTET: PostgreSQL-Verbindung wurde blockiert"
fi
```

Erfolg: Redis ist erreichbar, PostgreSQL vom Vote-Pod aus nicht. Die Terminalausgaben als Textnachweis speichern.

## 13. Monitoring und Belege

Grafana-URL oeffnen, mit `admin` und dem nur im Terminal gesetzten Grafana-Kennwort anmelden und das Dashboard `Portable Voting App / Kubernetes Overview` anzeigen. Screenshot mit URL, Dashboardtitel, Podstatus und Zeitpunkt erstellen. Das Kennwort darf nicht sichtbar sein.

Maschinenlesbare Nachweise sammeln:

```bash
./scripts/collect-evidence.sh gke
```

Danach `docs/gke-ergebnisse-VORLAGE.md` vollstaendig ausfuellen. Fehler und Abweichungen ebenfalls dokumentieren; ein sauber erklaertes negatives Ergebnis ist wissenschaftlich besser als ein erfundener Erfolg.

## 14. Abbau und Kostenkontrolle

```bash
terraform -chdir=infra/gke destroy \
  -var "project_id=${PROJECT_ID}" \
  -var "location=${GKE_LOCATION}" \
  -var "image_tag=${IMAGE_TAG}"

gcloud container clusters list --project "$PROJECT_ID"
gcloud compute forwarding-rules list --project "$PROJECT_ID"
gcloud compute addresses list --project "$PROJECT_ID"
gcloud compute disks list --project "$PROJECT_ID"
```

Erwartung: Der Versuchscluster und die von ihm erzeugten Ressourcen sind nicht mehr vorhanden. Wegen asynchroner Cloud-Loeschung einige Minuten warten und erneut pruefen.

## Fehlerdiagnose

| Symptom | Pruefung | Typische Ursache |
|---|---|---|
| `403` bei API-Aktivierung | IAM und Billing pruefen | fehlende Rechte oder Abrechnung |
| Node Pool bleibt fehlerhaft | GCE-Quote und Zone pruefen | CPU-/IP-Quote oder Kapazitaet |
| `ImagePullBackOff` | `kubectl describe pod` | falscher SHA, Pfad oder private GHCR-Pakete |
| Traefik ohne externe IP | Service und GCP-Events pruefen | Quote, IP-Region oder Load-Balancer-Fehler |
| PVC `Pending` | `kubectl describe pvc` | StorageClass oder CSI-Bereitstellung |
| Ingress antwortet nicht | DNS-Host, Service, Endpoints und Traefik-Logs pruefen | Adresse noch nicht aktiv oder Backend nicht Ready |
| T4 erlaubt PostgreSQL | NetworkPolicies und Dataplane V2 pruefen | Policy nicht angewendet oder falscher Selektor |

Jede Abweichung mit Befehl, Zeitstempel, Ausgabe, Ursache und Behebung in der Ergebnisvorlage festhalten.
