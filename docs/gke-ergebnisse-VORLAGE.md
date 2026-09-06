# Ergebnisprotokoll des gemeinsamen Testplans

Nur tatsaechlich erhobene Werte eintragen. Leere Angaben bedeuten NOT_RUN, nicht PASS. Ausfuehrung und Voraussetzungen stehen in `evaluation-runbook.md`. Diese Vorlage startet keine Cloud-Ressourcen.

## Rahmen und Herkunft

| Angabe | Wert / Nachweis |
|---|---|
| Datum, Zeitzone und Bearbeiter | |
| Expliziter Kontext / Namespace / Release | |
| Gesonderte GKE-Freigabe, Testkonto, Guthaben, vorhandene Kapazitaet | |
| Vollstaendiger Commit und sauberer Quellstand | |
| Buildrecord / Quellhash / Architektur / Build-Digest | |
| Tatsaechliche Image-IDs und Knotenarchitekturen | |
| Kubernetes-, kubectl-, Helm- und Terraform-Version | |
| Eigene Namespace-, PVC- und PV-UIDs | |
| Replikate Vote/Result/Worker/Redis/PostgreSQL | 2 / 2 / 1 / 1 / 1 |
| Test-Ingress-Hosts ohne Demo-Daten | |

## Ergebnisse

Jede Umgebung hat drei Wiederholungen. Zustaende: PASS, FAIL, ERROR, NOT_RUN. Keine pauschale Erfolgsaussage aus einem Exitcode oder Screenshot.

| Pruefung | Wiederholung 1 | 2 | 3 | Rohdateien |
|---|---|---|---|---|
| T1: beide Optionen, Stimmaenderung, exakte Zeilen, WebSocket und Anzeige | | | | |
| T2: neuer PostgreSQL-Pod, gleiches PVC/PV, alle Testzeilen, Result/Worker ohne Prozessneustart | | | | |
| T3: zwei neue bereite Vote-UIDs und erneute Fachfunktion | | | | |
| T4: DNS und bereiter PostgreSQL-Endpunkt; gleicher Weg mit/ohne enge Kontrollregeln, zweimal | | | | |
| Monitoring: echte Prometheus-Daten direkt und ueber Grafana-Datenquelle | | | | |

## Aufwand und Fehler

| Beginn / Ende | Schritt | Befehlsdauer | Aktive Bedienzeit separat | Status / Fehler / Wiederholung |
|---|---|---|---|---|
| | | | | |

Die Testinstallation im vorhandenen GKE-Cluster ist kein vollstaendiger Cloud-Neuaufbau. Zeiten eines Testzyklus enthalten auch Warte- und Pruefschritte und duerfen nicht als Ausfallzeiten bezeichnet werden.

## Anpassungsmatrix

| Abweichung | Ursache | Umsetzung | Erforderlicher Nachweis | Erhoben? |
|---|---|---|---|---|
| Speicherklasse | Plattformintegration | Zielwert local-path / standard-rwo | PVC/PV und T2 | |
| DNS-/Probe-Pfade | Netzwerkintegration | konkret gepruefte Selektoren und CIDR | Endpunkte, T4, Probes | |
| Hosts / Image-Bezug | Umgebungsparameter | Values / Build- und Importweg | Zugriff und Runtime-Digests | |
| Replikate | Gemeinsame Versuchsentscheidung | je zwei Vote/Result | bereite Pods, T3 | |
| Cluster / externer Zugriff | Infrastruktur | getrennte Module | historische bzw. neue Belege trennen | |

Keine Portabilitaets-Prozentzahl bilden. Statische Beispielrenderings und reale Runtime-Snapshots sind unterschiedliche Nachweistypen.

## Abschluss

Rohdaten und Pruefsummen sichern. Aenderungen nach einem Fehler erfordern einen neuen zugeordneten Build und betroffene Wiederholungen. Demo und historische Nachweise nicht ueberschreiben. Testressourcen ausschliesslich gezielt und nach Freigabe abbauen; insbesondere kein `terraform destroy` des gemeinsamen GKE-Clusters.
