# Portable Kubernetes Management Environment

Dieser Prototyp untersucht Kubernetes als Grundlage einer portierbaren, containerzentrierten Managementumgebung. Dieselbe Anwendung und dasselbe Helm-Chart werden lokal auf K3d/K3s und in Google Kubernetes Engine (GKE) eingesetzt. Terraform verwaltet die plattformspezifische Infrastruktur und die gemeinsamen Add-ons.

Der Prototyp ist ein Demonstrator fuer eine Bachelorarbeit. Er ist keine produktionsreife Plattform und ersetzt keine Messung in den beiden Zielumgebungen.

## Architektur

- Kubernetes lokal: K3d/K3s, ein Server und zwei Agenten
- Kubernetes Cloud: zonaler GKE-Standardcluster mit separatem Node Pool
- Routing: Traefik `41.0.2` und die stabile Kubernetes-Ingress-API
- Paketierung: gemeinsames Helm-Chart unter `charts/voting-app`
- Bereitstellung: Terraform unter `infra/onprem-k3d` und `infra/gke`
- Beobachtbarkeit: Prometheus und Grafana
- Sicherheitsbasis: Pod Security Admission, Non-Root-Container, minimale ServiceAccounts/RBAC-Rechte und NetworkPolicies
- Persistenz: PostgreSQL als StatefulSet mit PVC

Die Ingress-API ist stabil, wird von Kubernetes jedoch nicht mehr erweitert. Eine Migration auf Gateway API ist deshalb als Weiterentwicklung dokumentiert. `ingress-nginx` wird nicht eingesetzt, da das Projekt seit Maerz 2026 eingestellt ist.

## Anwendung

| Komponente | Aufgabe | Laufzeit |
|---|---|---|
| `vote` | Stimme erfassen und in Redis schreiben | Python 3.13 / Flask |
| `redis` | Warteschlange | Redis 7.4.9 |
| `worker` | Stimmen aus Redis nach PostgreSQL uebertragen | .NET 10 LTS |
| `postgres` | Stimmen persistent speichern | PostgreSQL 16 |
| `result` | aggregierte Ergebnisse anzeigen | Node.js 24 LTS |

Die beiden Browseroberflaechen verwenden nur mitgelieferte Assets. Die alte
AngularJS- und CDN-Abhaengigkeit der Referenzanwendung ist im Prototyp entfernt.

Die Dateien `docker-compose*.yml`, `docker-stack.yml` und `k8s-specifications/`
dokumentieren den analysierten Ausgangsstand der Referenzanwendung. Der in der
Arbeit bewertete Prototyp wird ausschliesslich ueber das gemeinsame Helm-Chart
und die beiden Terraform-Module bereitgestellt.

## Lokaler Schnellstart (macOS/Linux)

Docker Desktop starten und im Projektverzeichnis ausfuehren:

```bash
make tools-check
make local
```

Der kombinierte Lauf erzeugt den Cluster, baut und importiert die drei Images, initialisiert Terraform, installiert die Releases und zeigt Pods sowie URLs. Die Einzelschritte lauten:

```bash
./scripts/cluster-up.sh
./scripts/build-local.sh
./scripts/tf-init.sh
./scripts/tf-apply.sh
./scripts/pods.sh
./scripts/urls.sh
```

Lokale Endpunkte:

- Vote: `http://vote.127.0.0.1.nip.io:8080`
- Result: `http://result.127.0.0.1.nip.io:8080`
- Grafana: `http://grafana.127.0.0.1.nip.io:8080`

Das lokale Grafana-Laborkonto lautet standardmaessig `admin` / `admin`. Dieses Kennwort ist ausschliesslich fuer den lokalen Demonstrator vorgesehen.

## Windows

Die bestehenden PowerShell-Skripte bleiben erhalten. Beispiel:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tools-check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cluster-up.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-local.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tf-init.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tf-apply.ps1
```

Die entsprechenden Make-Ziele enden auf `-ps`, zum Beispiel `make validate-ps`.
`install-tools.ps1` installiert nur Helm, Terraform, k3d und GitHub CLI portabel.
Docker Desktop, kubectl, Python, Node.js/npm und Ruby muessen auf Windows separat im
`PATH` vorhanden sein; `tools-check.ps1` prueft dies vor dem Lauf.

## Validierung

```bash
make validate
```

Der Lauf prueft Helm, beide Terraform-Module, die Vote-Anwendung mit isolierten Tests,
die Node-Anwendung samt npm-Sicherheitsaudit sowie den statischen Manifestvergleich.
Terraform-Provider, Python- und npm-Abhaengigkeiten benoetigen beim ersten Lauf
Internetzugriff.

Nur den Portabilitaetsvergleich ausfuehren:

```bash
make portability
```

Die erzeugten Nachweise liegen unter:

- `evidence/portability-comparison.json`
- `evidence/portability-comparison.md`

Aktueller statischer Befund: 35 von 35 Objektidentitaeten werden wiederverwendet; 98,69 % der verglichenen Blattwerte sind gleich. Die acht Unterschiede betreffen ausschliesslich Image-Referenzen, Replikate, externe Hostnamen und StorageClass. Das ist kein Laufzeitnachweis.

## Laufzeitnachweise

Nach einer echten Bereitstellung werden maschinenlesbare Nachweise gesammelt:

```bash
./scripts/collect-evidence.sh local
./scripts/collect-evidence.sh gke
```

Die Ausgabe wird zeitgestempelt unter `evidence/` abgelegt. Screenshots werden zusaetzlich nach der Checkliste in `docs/gke-ergebnisse-VORLAGE.md` erstellt.

## GKE

Die vollstaendige Anleitung befindet sich in `docs/gke-deployment.md`. Terraform reserviert vorab eine regionale IP und leitet daraus die nip.io-Hostnamen ab. Dadurch genuegt ein geplanter Terraform-Durchlauf; eine manuelle Aenderung von Helm-Werten zwischen zwei Laeufen ist nicht erforderlich.

Fuer GKE sind ein unveraenderlicher Commit-SHA als `image_tag` sowie sichere PostgreSQL- und Grafana-Kennwoerter Pflicht. Nach dem Versuch muss die Umgebung mit `terraform destroy` abgebaut werden, weil Cluster, Compute, Load Balancer und Persistent Disk Kosten verursachen.

## Grenzen

- K3d simuliert eine lokale On-Premise-nahe Umgebung, aber keine reale Unternehmensinfrastruktur.
- PostgreSQL hat eine Instanz, kein automatisches Backup und kein clusteruebergreifendes Restore-Verfahren.
- Redis verwendet im Demonstrator `emptyDir`; noch nicht verarbeitete Stimmen koennen bei einem Redis-Pod-Verlust verloren gehen.
- nip.io und HTTP dienen nur dem Experiment; produktiv sind kontrolliertes DNS und TLS erforderlich.
- Terraform-Zustand kann Geheimnisse enthalten und darf nicht versioniert werden.
- Portabilitaet bedeutet hier kontrollierte Anpassbarkeit, nicht voellige Unabhaengigkeit von Infrastruktur und Cloud-Diensten.

Weitere Dokumente:

- `docs/architecture.md`
- `docs/security.md`
- `docs/portability-evaluation.md`
- `docs/local-deployment.md`
- `docs/gke-deployment.md`
- `docs/gke-ergebnisse-VORLAGE.md`
- `docs/gitops.md`
