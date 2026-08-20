# Ergebnisprotokoll fuer Kapitel 6

Diese Datei erst nach einer realen Durchfuehrung ausfuellen. Leere Felder bedeuten `nicht erhoben`, nicht `bestanden`.

## A. Versionen und Rahmen

| Angabe | Tatsachlicher Wert |
|---|---|
| Durchfuehrungsdatum mit Zeitzone | |
| Bearbeiter | |
| Git-Commit-SHA | |
| Terraform-Version | |
| Helm-Version | |
| kubectl-Version | |
| GKE-Version | |
| GCP-Projekt (ggf. anonymisiert) | |
| Zone | |
| Node-Anzahl und Maschinentyp | |
| Reservierte Ingress-IP | |

## B. Bereitstellung

| Angabe | Tatsachlicher Wert / Nachweisdatei |
|---|---|
| Startzeit `terraform apply` | |
| Endzeit | |
| Gemessene Dauer | |
| Terraform-Zusammenfassung | |
| Anzahl laufender Voting-Pods | |
| Traefik-IP entspricht Terraform-Output | ja / nein / nicht erhoben |
| Abweichungen oder manuelle Eingriffe | |

## C. Testmatrix

| Test | Lokal | GKE | Objektiver Nachweis |
|---|---|---|---|
| T1 Vote zu Result | bestanden / fehlgeschlagen / nicht erhoben | bestanden / fehlgeschlagen / nicht erhoben | Screenshot + Health-Ausgabe |
| T2 PostgreSQL-Persistenz nach Pod-Ersatz | bestanden / fehlgeschlagen / nicht erhoben | bestanden / fehlgeschlagen / nicht erhoben | `t2-before.txt`, `t2-after.txt`, `diff` |
| T3 Wiederherstellung der Vote-Replikate | bestanden / fehlgeschlagen / nicht erhoben | bestanden / fehlgeschlagen / nicht erhoben | Podnamen und UIDs vor/nach Loeschung |
| T4 NetworkPolicy erlaubt Redis, sperrt PostgreSQL | bestanden / fehlgeschlagen / nicht erhoben | bestanden / fehlgeschlagen / nicht erhoben | Terminalausgaben beider Verbindungen |

## D. Screenshots

Dateinamen ohne Leerzeichen verwenden und keine Kennwoerter oder Tokens zeigen.

1. `gke-01-terraform-apply.png` - Apply-Zusammenfassung.
2. `gke-02-nodes-pods.png` - Nodes und sieben Voting-Pods.
3. `gke-03-vote.png` - Vote-Oberflaeche mit URL.
4. `gke-04-result.png` - Result-Oberflaeche mit URL und abgegebener Stimme.
5. `gke-05-persistenz.png` - Ergebnis nach PostgreSQL-Pod-Ersatz.
6. `gke-06-self-healing.png` - neue Vote-Pods.
7. `gke-07-grafana.png` - Dashboard mit sichtbarem Titel.
8. `gke-08-destroy.png` - Destroy-Zusammenfassung.

## E. Abweichungsprotokoll

| Zeitpunkt | Befehl/Test | Beobachtung | Ursache | Aenderung | Wiederholung erfolgreich? |
|---|---|---|---|---|---|
| | | | | | |

## F. Statische Portabilitaetswerte

Diese Werte fuer jeden finalen Commit neu aus `evidence/portability-comparison.json` uebernehmen.

| Kennzahl | Wert |
|---|---:|
| Objekte lokal | |
| Objekte GKE | |
| gemeinsame Objektidentitaeten | |
| Objektwiederverwendung | |
| Wiederverwendung der Blattwerte | |
| erwartete Unterschiede | |
| unerwartete Unterschiede | |

## G. Formulierungsschablone

Nur mit gemessenen Werten verwenden:

> Die GKE-Bereitstellung wurde am [Datum, Zeitzone] aus dem Commit [SHA] in der Zone [Zone] durchgefuehrt. Der gepruefte Terraform-Plan wurde in [Dauer] angewendet und endete mit [Zusammenfassung]. Im Zielzustand waren [Anzahl] Anwendungs-Pods Ready. T1 [Ergebnis], T2 [Ergebnis], T3 [Ergebnis] und T4 [Ergebnis]. [Abweichungen und Behebung]. Die statische Analyse zeigte [Werte]; diese wird durch die getrennt erhobenen Laufzeitnachweise ergaenzt.

## H. Abbau

| Kontrolle | Ergebnis |
|---|---|
| `terraform destroy` abgeschlossen | |
| GKE-Cluster nicht mehr vorhanden | |
| Forwarding Rules nicht mehr vorhanden | |
| reservierte IP nicht mehr vorhanden | |
| projektbezogene Versuchsdisk nicht mehr vorhanden | |
| Abschlusszeit | |
