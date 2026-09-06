# Vergleich der Betriebsbausteine

Stand: 07.09.2026. Quellinspektion der beiden `infra/*/main.tf`, kein
neuer Clusterlauf. Dieser Vergleich ergaenzt den Anwendungs-Chart-Comparator.

| Ebene | Gemeinsam | Zielanpassung oder Grenze | Nachweis |
|---|---|---|---|
| Anwendung | Ein Chart, je zwei Vote/Result, uebrige Komponenten einfach | Speicherklasse, Hosts, Images, DNS und Probe-Adresse | Comparator prueft Beispielprofile; Terraform-Werte und tatsaechliche Installation zusaetzlich pruefen |
| Ingress | Traefik-Chart 41.0.2, hostbasierte Regeln, Service LoadBalancer | Lokal k3d-Portabbildung; GKE zugeordnete Google-IP und Cloud-Lastverteiler | Terraform-Konfiguration, historische Aufbauprotokolle; neuer externer Zugriff offen |
| Monitoring | Prometheus 29.6.0, Grafana 10.5.15, gleiche sechs Panels und Prometheus-Datenquelle | Host und Namespaces; Cloud-eigene gmp-system-Komponenten sind nicht Teil dieses Stacks | Namespace-Ausdruecke durch Terraform offline ausgewertet; reale Zielabfragen weiterhin erforderlich |
| Ressourcen | Explizite Requests/Limits der Monitoring- und Hilfscontainer | Gleiche Werte bedeuten keine gleiche Leistung oder ausreichende Kapazitaet | Gespeicherte Helm-Renderings; keine Lastmessung |
| Speicherung | PostgreSQL-PVC, 1 GiB | local-path bzw. standard-rwo; verschiedene Provisioner | PVC/PV-Zuordnung und T2; kein Datentransfer zwischen Clustern |
| Images/Zugang | Gleicher Anwendungscode, revisionsbezogene Builds | ARM64/AMD64, lokaler Import bzw. Registry und imagePullSecret | Commit/Build/Runtime-Zuordnung offen fuer den neuen Stand |
| Infrastruktur | Deklarative Definitionen und getrennte Zustandsdateien | k3d lokal; Google-APIs, Cluster, Nodepool, IP und Identitaeten in GKE | Quellinspektion und historische Protokolle; kein neuer GKE-Aufbau |

Die GKE-Abfragen waren bis fbdd130 teilweise auf `voting` und die Datenquelle
auf `monitoring` festgelegt. Die Korrektur bindet beide an die angebotenen
Variablen. `test_monitoring.py` wertet die Originalausdruecke mit Terraform
unter `voting-test-review` und `metrics-test-review` in einem providerfreien
Verzeichnis aus. Ein zweiter Test vergleicht die vollstaendigen Dashboard-
Definitionen. Diese bleiben bewusst in beiden vorhandenen Modulen erhalten;
eine zentrale Moduldatei ist noch nicht umgesetzt. Der Gleichheitstest
erkennt kuenftige Abweichungen, beseitigt aber nicht die doppelte Pflege.

Tagbasierte Redis-/PostgreSQL-Images sind nicht unveraenderlich fixiert.
Der Runner archiviert deren Runtime-IDs, prueft aber nur bei Vote, Result und
Worker gegen den Buildrecord. Vor einem finalen Wiederholbarkeitsanspruch
muessen auch die verwendeten Fremdimages architekturbezogen festgelegt und
mit den Zielnachweisen verbunden werden. Keine Digests werden geraten.
