# Portabilitaetsevaluation

## Untersuchungslogik

Die Evaluation trennt drei Evidenzarten:

1. **Statische Evidenz:** Vergleich der lokal und fuer GKE gerenderten Helm-Manifeste.
2. **Bereitstellungsevidenz:** Terraform-, Helm- und Kubernetes-Ausgaben aus jeder realen Zielumgebung.
3. **Laufzeitevidenz:** reproduzierbare Tests T1 bis T4 mit Zeitstempel und Nachweisdatei.

Statische Ergebnisse duerfen nicht als erfolgreiche Cloud-Bereitstellung bezeichnet werden.

## Kriterien

| Kriterium | Operationalisierung | Evidenz |
|---|---|---|
| K1 Artefaktwiederverwendung | gleiche Kubernetes-Objektidentitaeten in beiden Renderings | `evidence/portability-comparison.json` |
| K2 Begrenzte Anpassung | Unterschiede nur in vorab definierten Parameterklassen | statischer Felddiff |
| K3 Reproduzierbarkeit | Bereitstellung aus dokumentierten Befehlen und versionierten Dateien | Terraform-/Helm-Ausgaben |
| K4 Funktionsfaehigkeit | Vote wird nach dem Durchstich in Result angezeigt | T1 je Umgebung |
| K5 Betriebsverhalten | Persistenz, Selbstheilung und Policy-Durchsetzung funktionieren | T2 bis T4 je Umgebung |
| K6 Grenzen | verbleibende Provider-, Storage-, Netzwerk- und Betriebsbindung ist dokumentiert | Analyse und Fehlerprotokoll |

## Statischer Befund

`scripts/compare-portability.rb` rendert beide Values-Varianten und vergleicht alle Objekte strukturiert. Der aktuelle Stand ergibt:

- 35 lokale und 35 GKE-Objekte,
- 35 gemeinsame Objektidentitaeten und damit 100 % Objektwiederverwendung,
- 602 von 613 beziehungsweise 98,21 % gleiche Blattwerte,
- elf erwartete Unterschiede in fuenf Kategorien,
- keine unerwartete Abweichung.

Die elf Unterschiede sind drei Image-Referenzen, zwei Replikatzahlen, zwei externe Hostnamen, drei Plattform-Netzwerkwerte und eine StorageClass. Die Werte belegen eine weitgehende Wiederverwendung der Anwendungsmanifeste, nicht die vollstaendige Infrastrukturunabhaengigkeit.

## Laufzeittests

| Test | Ziel | Erfolgskriterium |
|---|---|---|
| T1 Durchstich | Ende-zu-Ende-Funktion | abgegebene Stimme erscheint in Result |
| T2 Persistenz | Zustand nach Pod-Ersatz | Tabelleninhalt vor und nach PostgreSQL-Pod-Neustart ist gleich |
| T3 Selbstheilung | Controllerverhalten | geloeschte Vote-Pods werden ersetzt und alle Replikate sind wieder Ready |
| T4 Netzisolation | Policy-Wirkung | Vote erreicht Redis, aber nicht PostgreSQL |

Die Befehle und Nachweisfelder stehen in `docs/gke-deployment.md` und `docs/gke-ergebnisse-VORLAGE.md`.

Der reale GKE-Lauf vom 20.08.2026 und der finale lokale Lauf vom 02.09.2026 bestanden jeweils T1 bis T4. Ihre Nachweise liegen unter `evidence/gke-20260820T105218Z/` und `evidence/local-20260902T142914Z/`. K4 und K5 sind damit fuer die definierten Testszenarien in beiden Zielumgebungen erfuellt. Daraus folgt kein Nachweis fuer Hochverfuegbarkeit, Backup, Lastfestigkeit oder beliebige andere Anwendungen.

## Umgebungsbindung

- K3d-Portabbildungen sind spezifisch fuer den lokalen Docker-Host.
- GKE erfordert Projekt, Abrechnung, IAM, API-Aktivierung und regionale Ressourcen.
- nip.io ist eine Experimenthilfe und kein produktives DNS-Modell.
- StorageClass, Volume-Implementierung und Datenmigration bleiben infrastrukturspezifisch.
- NetworkPolicy-Verhalten haengt vom CNI ab.
- Oeffentliche oder authentifizierte Registry-Erreichbarkeit muss je Umgebung geloest werden.

## Gueltigkeitsgrenzen

Der Demonstrator untersucht eine Anwendung, zwei konkrete Zielumgebungen und einen kurzen Beobachtungszeitraum. Er erlaubt keine Aussage ueber alle Kubernetes-Distributionen, Langzeitbetrieb, Hochverfuegbarkeit, Lastspitzen oder eine vollstaendige Cloud-Migration. K3d ist eine lokale Naeherung an On-Premise und kein Ersatz fuer einen realen Bare-Metal- oder Virtualisierungscluster.
