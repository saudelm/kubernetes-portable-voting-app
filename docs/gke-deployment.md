# GKE: Freigegebene Evaluation im bestehenden Cluster

## Verbindliche Grenzen

Der aktuelle Ueberarbeitungsauftrag erlaubt **noch keinen Cloud-Test**.
Vorher sind ausdrueckliche Freigabe, aktiver Testkontostatus, verbleibendes
Guthaben, Ablaufdatum und tatsaechliche freie Clusterkapazitaet zu pruefen.

- Niemals Activate/Upgrade beziehungsweise ein Vollkonto aktivieren.
- Kein weiterer Cluster, kein neuer Node Pool, keine Autoskalierung oder Knotenerweiterung.
- Kein neuer Load Balancer; vorhandenen Ingress nutzen.
- Keine Demo-Daten veraendern, keine vorhandenen Volumes wiederverwenden.
- Kein Terraform-Apply oder Destroy gegen die bestehende Demo.
- Ein eigener Test-PVC kann Guthaben verbrauchen. Ohne gepruefte Bedingungen nicht anlegen.

Das Infrastrukturmodul `infra/gke` bleibt als Implementierungsartefakt erhalten.
Seine Existenz ist keine Freigabe, damit einen neuen Cluster aufzubauen.

## Vorpruefung nach Freigabe

1. In der Cloud-Konsole das Projekt portable-kubernetes-saud und den Testkontostatus kontrollieren.
2. Guthaben, Ablauf und Hinweise auf moegliche Berechnung dokumentieren, ohne persoenliche Zahlungsdaten zu exportieren.
3. Den vorhandenen Kontext und Cluster verifizieren. Nur explizite Kontexte verwenden; keine globale Kontextumschaltung.
4. Knoten, allocatable/angeforderte Ressourcen, aktuelle Auslastung und Speicherquote pruefen.
5. Sicherstellen, dass die sieben Anwendungspods mit Limits/Requests und eigenem Speicher in die vorhandene Kapazitaet passen.
6. Falls Kapazitaet fehlt: NOT_RUN dokumentieren. Nicht automatisch skalieren.

Die Bedingungen und Freigabe werden fuer den Runner in einer lokalen JSON-Datei
festgehalten. Die Datei ist ein Protokoll der echten menschlichen Freigabe,
keine Berechtigung, diese Freigabe selbst zu erfinden.

## Getrennte Installation

Ein neuer Namespace `voting-test-<kennung>` erhaelt ausschliesslich den neuen
Test-Release mit eigenem PVC. Die Markierung und das Release muessen zu den
Runner-Argumenten passen. Verwendet werden:

- das unveraenderte gemeinsame Chart aus dem final festgelegten Quellstand;
- GKE-Werte fuer Storage, DNS und Probe-Zugriff aus dem tatsaechlichen Cluster;
- zwei Vote- und zwei Result-Replikate;
- Images desselben Commits fuer die Architektur der vorhandenen Knoten;
- eindeutige Hosts, die nicht mit der Demo kollidieren;
- externe Test-Zugangsdaten und gegebenenfalls ein eigenes imagePullSecret.

Vorhandene Prometheus-/Grafana-Instanzen duerfen lesend verwendet werden,
sofern sie den Test-Namespace wirklich erfassen. Ihre Ressourcenlimits werden
nicht ohne Freigabe in einer laufenden Demo geaendert.

Konkrete Testbefehle, Erfolgskriterien und Protokollformat:
`docs/evaluation-runbook.md`. Vor einem neuen Lauf die dortigen Voraussetzungen
vollstaendig pruefen. Ein Diagramm oder ein statisch erfolgreiches Rendering
belegt keine reale Cloud-Ausfuehrung.

## Nach dem Versuch

Alle Nachweise inklusive Fehlern und Runtime-Image-IDs sichern.
Testinstallation und Test-PVC nur gezielt und nach vereinbarter Freigabe abbauen.
Die vorhandene Demo und historische Evidenz bleiben erhalten.
Kein pauschales `terraform destroy`, kein Loeschen des Clusters.

Budgetwarnungen sind keine technische Kostensperre. Fuer aktuelle Bedingungen
die offiziellen Google-Cloud-Seiten und den tatsaechlichen Kontostatus pruefen;
dieses Repository gibt keine Kostengarantie.
