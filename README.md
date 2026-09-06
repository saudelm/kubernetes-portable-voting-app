# Portable Kubernetes Management Environment

Dieser Prototyp untersucht Kubernetes als Grundlage einer portierbaren, containerzentrierten Managementumgebung. Dieselbe Anwendung und dasselbe Helm-Chart werden lokal auf K3d/K3s und in Google Kubernetes Engine (GKE) eingesetzt. Terraform verwaltet die plattformspezifische Infrastruktur und die gemeinsamen Add-ons.

Der Prototyp ist ein Demonstrator fuer eine Bachelorarbeit und keine produktionsreife Plattform. Die historischen Versuche ab August 2026 betreffen unterschiedliche Quell- und Image-Staende und teilweise schwaechere Tests. Sie bilden keinen gemeinsamen finalen Nachweis. Die aktuelle Ueberarbeitung verlangt einen neuen, zusammenhaengenden Lauf des festgelegten Quellstands in beiden Umgebungen. Ohne diesen Lauf bleibt die Abnahme offen.

## Architektur

- Kubernetes lokal: K3d/K3s, ein Server und zwei Agenten
- Kubernetes Cloud: zonaler GKE-Standardcluster mit separatem Node Pool
- Routing: Traefik `41.0.2` und die stabile Kubernetes-Ingress-API
- Paketierung: gemeinsames Helm-Chart unter `charts/voting-app`
- Bereitstellung: Terraform unter `infra/onprem-k3d` und `infra/gke`
- Beobachtbarkeit: Prometheus und Grafana
- Sicherheitsbasis: Pod Security Admission, Non-Root-Container, minimale ServiceAccounts/RBAC-Rechte und NetworkPolicies
- Persistenz: PostgreSQL als StatefulSet mit PVC

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

Seit der lokalen Konfigurationsanpassung vom 06.09.2026 sehen beide Values-Profile
je zwei Vote- und Result-Replikate vor. Mit Worker, Redis und PostgreSQL ergibt
das sieben Anwendungspods im stabilen Sollzustand. Dies ist eine gemeinsame
Versuchskonfiguration, keine GKE-Voraussetzung und kein Hochverfuegbarkeitsnachweis.
Die historischen lokalen Versuche mit insgesamt fuenf Pods bleiben unveraendert.
Das Angleichen der Replikazahlen ersetzt keinen vollstaendigen finalen Testlauf.

Die Dateien `docker-compose*.yml`, `docker-stack.yml` und `k8s-specifications/`
dokumentieren den analysierten Ausgangsstand der Referenzanwendung. Der in der
Arbeit bewertete Prototyp wird ausschliesslich ueber das gemeinsame Helm-Chart
und die beiden Terraform-Module bereitgestellt.

## Lokaler Schnellstart (macOS/Linux)

Docker Desktop starten und im Projektverzeichnis ausfuehren:

**Nur fuer eine neue Demo-Installation.** Eine vorhandene Demo nicht mit diesen
Aufbaubefehlen ueberschreiben. Die isolierten Evaluationslaeufe stehen in
`docs/evaluation-runbook.md`. Kennwoerter fuer neue Installationen extern setzen:

```bash
export TF_VAR_postgres_password="$(openssl rand -base64 24)"
export TF_VAR_grafana_admin_password="$(openssl rand -base64 24)"
```

```bash
./scripts/tools-check.sh
./scripts/cluster-up.sh
./scripts/build-local.sh
./scripts/tf-init.sh
./scripts/tf-apply.sh
```

Die Schritte erzeugen den Cluster, bauen und importieren die drei Images, initialisieren Terraform und installieren die Releases. Status und URLs zeigt:

```bash
./scripts/pods.sh
./scripts/urls.sh
```

`kubectl` sollte dieselbe Minor-Version wie der Cluster oder hoechstens eine benachbarte Version verwenden. Der dokumentierte Lauf nutzte Client `1.35.8` und Server `1.35.4+k3s1`. Auf dem verwendeten Apple-Silicon-Mac wurde der passende Client so vor den alten Client gesetzt:

```bash
export PATH="/opt/homebrew/opt/kubernetes-cli@1.35/bin:$PATH"
```

`make local` bleibt als Kurzform verfuegbar, sofern GNU Make installiert ist.

Lokale Endpunkte:

- Vote: `http://vote.127.0.0.1.nip.io:8080`
- Result: `http://result.127.0.0.1.nip.io:8080`
- Grafana: `http://grafana.127.0.0.1.nip.io:8080`

Grafana verwendet den Benutzer `admin` und das extern gesetzte Kennwort. Es gibt
im aktuellen Terraform-Modul keinen Kennwortdefault. Diese Quelltextaenderung
rotiert die Zugangsdaten einer bereits laufenden Demo nicht.

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
make portability OUTPUT=evidence/matrix-NEUER-LAUF
```

Die erzeugten Nachweise liegen unter:

- `evidence/matrix-NEUER-LAUF/adaptation-matrix.json`
- `evidence/matrix-NEUER-LAUF/adaptation-matrix.md`

Die bisher archivierte statische Auswertung gehoert zum historischen Profil mit
unterschiedlichen Vote-/Result-Replikazahlen. Sie beschreibt nicht die am
06.09.2026 angeglichenen Profile. Eine YAML-Gleichheitsquote ist kein geeignetes
Mass fuer die Portabilitaet der ganzen Umgebung. Die im Gutachten beschriebenen
Vergleichsfehler werden durch Regressionstests geprueft. Der neue Vergleich
erhaelt leere Strukturen und erlaubt nur konkrete Feld-Wert-Paare. Die Matrix
trennt Ursachen, Umsetzung und erforderliche Laufzeitnachweise. Ein statischer
PASS ersetzt keinen Laufzeittest. Historische Auswertungen nicht ueberschreiben.

## Laufzeitnachweise

Der gemeinsame Runner verlangt explizite Ziele und lehnt den lokalen Demo-Kontext
und unmarkierte Namespaces ab. Er prueft T1 bis T4 jeweils dreimal. Er unterscheidet
`PASS`, `FAIL`, `ERROR` und `NOT_RUN`; die konkrete Aufrufanleitung steht in
`docs/evaluation-runbook.md`.

```bash
python3 scripts/evidence_runner.py --help
```

Die einfachere Zustandsaufnahme und die GKE-Variante bleiben getrennt verfuegbar:

```bash
./scripts/collect-evidence.sh local
./scripts/collect-evidence.sh gke
```

Historische Nachweise liegen unter `evidence/local-20260902T142914Z/` und
`evidence/gke-20260820T105218Z/`. Sie bleiben unveraendert und duerfen nicht dem
neuen Quellstand zugeschrieben werden. Zustandsaufnahmen allein sind kein
bestandener Testrun. Neue Ausgaben muessen in einem neuen Verzeichnis liegen.

## GKE

Die Grenzen fuer einen erneuten Versuch stehen in `docs/gke-deployment.md`.
Der aktuelle Auftrag erlaubt nach gesonderter Freigabe nur eine Testinstallation
im bestehenden Cluster. Kein Konto-Upgrade, kein neuer Cluster, kein neuer
Load Balancer und keine automatische Ressourcenerweiterung. Das vorhandene
Terraform-Infrastrukturmodul ist kein Auftrag, die Cloud neu aufzubauen.

Fuer GKE sind ein eindeutig zugeordnetes Image und externe Kennwoerter Pflicht.
Der Versuch vom 20.08.2026 nutzte den Commit
`82cde44a838d36f07cc47d9f29351d039cdf0244`. Sein damaliger Abbaunachweis sagt
nichts ueber den heutigen Cloud-Zustand aus. Die Demo wird nicht geloescht.

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
