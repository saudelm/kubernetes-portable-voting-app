# Portabilitaetsevaluation

## Gegenstand und Nachweisgrenzen

Untersucht werden die Bereitstellung derselben Anwendung mit einem gemeinsamen
Helm-Chart und ausgewaehlte Betriebseigenschaften auf K3d/K3s und GKE.
Datenmigration ist nicht Gegenstand. T2 prueft Datenerhalt auf demselben Volume.
Zwei Vote- und zwei Result-Replikate sind eine gemeinsame Versuchsentscheidung,
keine Voraussetzung fuer einen Load Balancer und keine Hochverfuegbarkeitsgarantie.
Worker, Redis und PostgreSQL besitzen jeweils eine Instanz.

## Kriterien

| Kriterium | Operationalisierung | Nachweis |
|---|---|---|
| K1 Artefaktwiederverwendung | Gemeinsames Chart, identische Objektidentitaeten; Unterschiede sichtbar | Quellstand und Anpassungsmatrix |
| K2 Begrenzte Anpassung | Konkrete Feld-Wert-Paare und begruendete Ursachen | Anpassungsmatrix und Werteprofile |
| K3 Keine unerwartete Abweichung | Jede nicht freigegebene Struktur- oder Wertaenderung fuehrt zu FAIL | Comparator und Regressionstests |
| K4 Funktion | Exakte Stimmenzeilen, Stimmaenderung und sichtbare Live-Ergebnisse | T1 in beiden Zielumgebungen |
| K5 Ausgewaehlter Betrieb | Gleicher Speicher, Pod-Ersatz, Wiederverbindung, kontrollierte Netzisolation und Monitoring | T2-T4 sowie echte Messdaten |
| K6 Beobachteter Aufwand | Neue Arbeitsschritte und Zeiten, Fehler und Wiederherstellung | Zeitprotokoll der neuen Laeufe |

K1-K3 sind statische Pruefungen. Ihre Erfuellung bedeutet nicht, dass K4-K6
ebenfalls erfuellt sind. Eine Prozentzahl fuer die Portabilitaet wird nicht berechnet.

## Statische Anpassungsmatrix

`scripts/compare-portability.rb` rendert zwei festgelegte Beispielprofile.
Leere Maps und Listen bleiben eigene Werte; fehlende Felder werden nicht mit
vorhandenen leeren Strukturen verwechselt. Doppelte Objektidentitaeten werden
abgelehnt. Nicht nur Feldnamen, sondern auch die erwarteten Werte sind begrenzt.

Die Beispiele verwenden Dokumentationsadressen und Testplatzhalter, keine
Laufzeit-Zugangsdaten. Die Matrix prueft dieses kanonische Profil, nicht beliebige
Live-Manifeste. Andere konkrete Hosts, Registry-Pfade oder CNI-Adressen muessen
gesondert aus dem realen Versuch dokumentiert werden.

| Kategorie | Beispiel | Einordnung |
|---|---|---|
| Plattformnotwendigkeit | lokale StorageClass gegen GKE-StorageClass | Unterschiedlicher Provisioner; PVC-Bindung und T2 notwendig |
| Plattformnotwendigkeit | GKE-DNS-Selektoren und Probe-Quelladresse | Vom tatsaechlichen Cluster abhaengig; DNS/Readiness/T4 pruefen |
| Umgebungsparameter | Registry-Pfade und Ingress-Hosts | Andere Bezugs- oder Zugriffsadresse; Image-IDs und Funktion pruefen |
| Gemeinsame Versuchsentscheidung | Vote=2, Result=2 | Kein Plattformunterschied; kein Hochverfuegbarkeitsnachweis |
| Infrastruktur | K3d/Docker gegen GKE-Netzwerk und Knoten | Nicht durch den Anwendungs-Chartvergleich abgedeckt |
| Anwendung | Plattformunabhaengiger Anwendungscode | Ein Quellstand, architekturgerechte Builds und echte Durchstiche erforderlich |

Beim aktuellen Beispielprofil sind neun konkrete Feldabweichungen vorgesehen.
Die Anzahl ist beschreibend, kein Qualitaetsmass. Ein falscher sicherheits- oder
speicherrelevanter Wert kann trotz zahlreicher gleicher Felder entscheidend sein.

## Laufzeitplan

Der verbindliche Ablauf steht in `docs/evaluation-runbook.md`.
Alle Tests laufen nur in einer eigens markierten Installation mit neuem Speicher
und anfangs leerer Stimmtabelle. Eine vorhandene Demo ist kein Testziel.

- T1: mehrere eindeutige Waehler, beide Optionen, eine Stimmaenderung; vollstaendige Zeilen und WebSocket/DOM pruefen.
- T2: PostgreSQL-Pod ersetzen; vollstaendige Zeilen, PVC/PV-Zuordnung und neue Pod-UID vergleichen; Result/Worker duerfen dabei nicht neu starten.
- T3: beide Vote-Pods ersetzen; neue UIDs und Ready-Zustand sowie anschliessende Fachfunktion pruefen.
- T4: DNS und Werkzeugausfuehrung separat pruefen; CONNECTED/BLOCKED zweimal gegen denselben PostgreSQL-Endpunkt mit eng begrenzten Kontrollregeln pruefen.
- Monitoring: echte Daten des Test-Namespaces in Prometheus und ueber die Grafana-Datenquelle abfragen.

T1-T4 werden je Umgebung dreimal mit demselben Runner ausgefuehrt.
Ein Werkzeugfehler ist ERROR, keine bestaetigte Netzsperre.
Nicht ausgefuehrte Pruefungen sind NOT_RUN. Fehlgeschlagene Laeufe bleiben erhalten.

## Historische und neue Evidenz

Die bisherigen Ordner dokumentieren reale fruehere Arbeiten, aber unterschiedliche
Images, Quellstaende und schwaechere Pruefkriterien. Sie werden nicht umetikettiert.
Erst ein sauberer finaler Commit, dessen Builds, tatsaechliche Runtime-Image-IDs
und neue Ergebnisse gemeinsam vorliegen, schliessen B4.

Ein neuer Lauf im bestehenden GKE-Cluster misst keinen kompletten Cloud-Neuaufbau.
Nur tatsaechlich beobachtete Schritte und Zeiten werden ausgewertet. Drei
Wiederholungen erlauben keine allgemeine Aussage ueber Verfuegbarkeit, Sicherheit,
Lastfestigkeit oder langfristigen Betrieb.

## Verbleibende Bindungen

Storage-Implementierung, CNI, Cloud-IAM, Registry-Zugriff, Clusterbetrieb und DNS
bleiben umgebungsabhaengig. Kubernetes abstrahiert diese Unterschiede nicht
vollstaendig. K3d ist eine Labornaeherung an On-Premise, kein Unternehmenscluster.
