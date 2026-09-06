# Reproduzierbarer Testlauf T1-T4

## 1. Voraussetzungen

Dieser Ablauf ist ein **Testplan**, kein bereits bestandener Nachweis.
Benutzt werden nur neue Testinstallationen. Eine vorhandene Demo bleibt erhalten.
Datenmigration, Backup und allgemeine Hochverfuegbarkeit werden nicht untersucht.

Erforderlich: Docker/K3d fuer lokal, kubectl, Helm, Terraform, Git, Python,
Ruby, Node.js und Playwright mit Chromium. Der gemeinsame Runner benoetigt
Playwright nur fuer echte Browser-/WebSocket-Pruefungen. Fehlende Werkzeuge
werden nicht als bestandene Tests gewertet.

## 2. Quellstand und Builds

1. Alle vorgesehenen Codekorrekturen und statischen Tests abschliessen.
2. Die relevanten Dateien gezielt committen. Historische Nachweise nicht umetikettieren oder versehentlich in den Code-Commit aufnehmen.
3. Den vollstaendigen Commit mit `git rev-parse HEAD` sichern; der finale Arbeitsstand muss sauber sein.
4. Die drei Images fuer jede benoetigte Architektur aus exakt diesem Commit bauen.

Beispiel fuer einen neuen ARM64-Build:

```bash
python3 scripts/build-evaluation.py \
  --mode final --platform linux/arm64 \
  --output .local/build-FINALE-KENNUNG-arm64
```

Fuer AMD64 denselben Befehl mit `linux/amd64` und einem neuen Ausgabeverzeichnis
verwenden. Lokal werden Images nur gebaut und geladen, nicht veroeffentlicht.
`--mode candidate` erlaubt Vorversuche mit nicht finalem Quelltext, erzeugt
aber ausdruecklich keinen finalen Commit-Nachweis.

Ein Registry-Push muss spaeter dieselben gebauten Images verwenden. Werden Images
von GitHub Actions neu gebaut, sind deren eigene Build- und Manifest-Digests
zu sichern; gleiche Tags beweisen keine Image-Identitaet. Nach einem Push die
Registry-Referenz und den konkreten Architektur-Digest im Buildprotokoll
nachweisbar ergaenzen, nicht frei schaetzen. Ein Build kann durch veraenderliche
Basisimage-Tags trotz gleichen Anwendungscodes abweichen.

## 3. Separate lokale Testinstallation

Docker muss genug Kapazitaet fuer Demo und Testcluster gleichzeitig haben.
Das Setup-Skript verweigert bei weniger als 7 GiB gemeldetem Docker-RAM den
Aufbau; eine Konfiguration mit 8 GiB ist hier die vorgesehene Untergrenze.
Diese Plausibilitaetspruefung ist keine Garantie fuer ausreichende freie Kapazitaet.

Neue Testkennwoerter ausserhalb von Git setzen und fuer den Lauf sicher behalten:

```bash
export TF_VAR_postgres_password="$(openssl rand -base64 24)"
export TF_VAR_grafana_admin_password="$(openssl rand -base64 24)"
export GRAFANA_PASSWORD="$TF_VAR_grafana_admin_password"
```

Kennung und freien Port bewusst festlegen. Das Beispiel ist nur fuer einen noch
nicht vorhandenen Cluster und einen noch nicht vorhandenen Ausgabeordner:

```bash
python3 scripts/setup-local-evaluation.py \
  --name voting-test-lauf01 --port 18080 \
  --build-record .local/build-FINALE-KENNUNG-arm64/build-record.json \
  --output .local/setup-lauf01 --execute
```

Das Skript erzeugt ein neues K3d/K3s-Labor mit einem Server und zwei Agenten,
eigener Kubeconfig und separatem Terraform-State. Es verweigert vorhandene
Cluster und Ausgabeordner. Ohne `--execute` wird nur vorbereitet.
Die Demo und die globale aktuelle Kubeconfig werden nicht umgeschaltet.

Die private Ausgabe enthaelt State/Plan/Kubeconfig und darf **nicht** in das
Abgabearchiv oder Git. Das bereinigte Setup-Protokoll, Quellpruefsummen und
Testergebnisse gehoeren hingegen zum Nachweis.

## 4. Gemeinsamer Aufruf

Die Werte aus dem echten Setup-/Buildprotokoll verwenden. Folgende Werte sind
Beispiele und muessen zur neu angelegten Installation passen:

```bash
export KUBECONFIG="$PWD/.local/setup-lauf01/kubeconfig"
export FINAL_COMMIT="$(git rev-parse HEAD)"
kubectl --context k3d-voting-test-lauf01 -n monitoring \
  port-forward --address 127.0.0.1 service/prometheus-server 19090:80
```

Den Port-Forward in einem eigenen Terminal offen halten. Der Runner laeuft
im zweiten Terminal mit derselben privaten Kubeconfig:

```bash
python3 scripts/evidence_runner.py \
  --context k3d-voting-test-lauf01 \
  --namespace voting-test-lauf01 --release voting-test-lauf01 \
  --mode final --source-commit "$FINAL_COMMIT" \
  --build-record .local/build-FINALE-KENNUNG-arm64/build-record.json \
  --output evidence/final-lokal-lauf01 \
  --vote-url http://vote.voting-test-lauf01.127.0.0.1.nip.io:18080 \
  --result-url http://result.voting-test-lauf01.127.0.0.1.nip.io:18080 \
  --prometheus-url http://127.0.0.1:19090 \
  --grafana-url http://grafana.voting-test-lauf01.127.0.0.1.nip.io:18080
```

`NODE_PATH` kann auf eine bestehende Playwright-Installation zeigen.
`PLAYWRIGHT_CHROMIUM_EXECUTABLE` kann ein installiertes Chromium/Chrome
festlegen. Alternativ Playwright/Chromium in einer separaten Werkzeugumgebung
installieren; nicht stillschweigend die Anwendungsabhaengigkeiten veraendern.

## 5. Schutzbedingungen

Der Runner verlangt explizit Kontext, Namespace, Release, Ausgabe, Commit,
Buildprotokoll, Modus und beide Anwendungs-URLs.

- Lokaler Demo-Kontext `k3d-portable-voting` wird immer abgelehnt.
- Lokaler Testkontext muss mit `k3d-voting-test-` beginnen.
- Namespace muss mit `voting-test-` beginnen, Label `testing.portable-voting/isolated=true` und Annotation `testing.portable-voting/release=<release>` tragen.
- Namespace darf keine fremden Workloads enthalten; initiale Stimmtabelle muss leer sein.
- Test-PVC muss zum Release gehoeren; sein PV darf nicht vor dem Test-Namespace erzeugt worden sein.
- Vote-URL muss nachweislich einen Pod der Testinstallation ausliefern.
- Runtime-Image-IDs und Knotenarchitektur muessen zum Buildprotokoll passen.
- Bestehende Ausgaben werden niemals ueberschrieben.

Nach einem fehlgeschlagenen Lauf die Daten und Ausgaben behalten. Erst nach
Fehleranalyse einen neuen Lauf mit neuer leerer Testinstallation planen.
Nicht manuell die Stimmtabelle loeschen, um eine Vorbedingung zu umgehen.

## 6. Was geprueft wird

| Test | Aktion | Erfolgskriterium |
|---|---|---|
| T1 | Drei neue Waehler, beide Optionen, eine geaenderte Stimme | Alle erwarteten Zeilen stimmen; echtes WebSocket-Ergebnis und sichtbare Gesamtzahl/Anteile stimmen |
| T2 | PostgreSQL-Pod ersetzen; waehrend der Wiederherstellung eine weitere Stimme abgeben | Neue PG-UID, gleiche PVC/PV-Zuordnung, vollstaendige vorherige Daten und neue Stimme; Result/Worker ohne Prozessneustart |
| T3 | Beide Vote-Pods ersetzen | Zwei neue UIDs, Ready, neue Stimme und funktionierende Anzeige |
| T4 | DNS pruefen, danach dasselbe PostgreSQL-Pod-IP-Ziel mit und ohne enge Kontrollfreigaben ansprechen | Zweimal CONNECTED/BLOCKED, Werkzeug und Ziel funktionsfaehig, urspruengliche Policies wiederhergestellt |
| Monitoring | Prometheus und Grafana-Datenquellenproxy abfragen | Tatsaechliche Metrik zeigt sieben laufende Anwendungspods im Test-Namespace |

T1-T4 laufen in drei aufeinanderfolgenden Wiederholungen. Die synthetischen
Daten wachsen dabei kontrolliert. T2 ist ein Same-Volume-Test und kein
Datentransfer zwischen lokal und GKE. T4 belegt nur die untersuchte Verbindung,
keine umfassende Sicherheitszertifizierung.

## 7. Ergebnis und Aufwand

`summary.json` unterscheidet PASS, FAIL, ERROR und NOT_RUN.
Bei FAIL oder ERROR bricht der Lauf ab; verbleibende Tests erhalten NOT_RUN.
Eine fehlerhafte Ausfuehrung von kubectl/Python/DNS ist ERROR, keine Netzsperre.

Die Ausgabe enthaelt Befehle mit Zeiten und Exitcodes, exakte Datenpruefungen,
Pod-/Container-IDs, Speicherdaten, T4-Kontrollbeobachtungen, Browserbilder,
Monitoringdaten und Pruefsummen. Geheimnisse duerfen nicht in Ausgaben landen.

Zusatzprotokoll pro Arbeitsschritt:

| Beginn/Ende (UTC) | Umgebung | Arbeitsschritt | Aktive Bedienzeit | Wartezeit | Fehler/Ursache/Korrektur | Nachweis |
|---|---|---|---|---|---|---|

Befehlslaufzeit und menschliche Bedienzeit sind verschiedene Groessen.
Nicht gemessene Bedienzeiten werden nicht rueckwirkend erfunden.
Ein Versuch im vorhandenen GKE-Cluster misst nicht dessen vollstaendigen Aufbau.

## 8. GKE-Zusatzfreigabe

Vor einem Cloud-Lauf gelten `docs/gke-deployment.md` und die menschliche
Freigabe. Der Runner verlangt zusaetzlich `--gke-approval <datei>`.
Das lokale JSON-Protokoll benoetigt:

```json
{
  "context": "TATSAECHLICHER_GKE_KONTEXT",
  "namespace": "voting-test-FREIGEGEBENE-KENNUNG",
  "approved": true,
  "trial_active": true,
  "remaining_credit": "TATSAECHLICH_ABGELESENER_BETRAG_MIT_WAEHRUNG",
  "capacity_checked": true,
  "upgrade_allowed": false,
  "checked_at_utc": "TATSAECHLICHER_ISO_ZEITPUNKT_MIT_ZEITZONE"
}
```

Die Pruefung darf beim Start hoechstens eine Stunde alt sein. Die Eintraege
nur nach tatsaechlicher Kontrolle und Freigabe ausfuellen. Ein Runner kann
menschliche Freigabe oder Guthaben nicht selbst bestaetigen.

## 9. Abnahme

Ein statischer PASS, ein Kandidatenbuild oder ein einzelner lokaler Lauf
schliesst B4 nicht. Erforderlich ist eine geschlossene Zuordnung:

**finaler Commit -> konkreter Build -> tatsaechlich ausgefuehrtes Image
-> drei Testwiederholungen je Umgebung -> passende Ergebnisdarstellung.**

Bleibt ein Teil offen, bleibt er auch im Abschlussbericht offen. Historische
Nachweise und laufende Demo werden nicht veraendert.

## 10. Praezisierung der Testmethode vom 07.09.2026

T1 oeffnet die Ergebnisseite vor der Stimmveraenderung. Der Browsercheck wartet
auf Ausgangswerte, sendet dieselbe Waehlerkennung mit der anderen Option und
verlangt neue WebSocket-Daten sowie die geaenderte Anzeige ohne Navigation.
Danach vergleicht der Runner erneut saemtliche Datenbankzeilen.

T2 ersetzt den PostgreSQL-Pod durch einen kontrollierten Zyklus des
StatefulSets von einer auf null und zurueck auf eine Replik. Dies ist eine
bewusste Aenderung gegenueber den historischen Pod-Loeschversuchen, keine
nachtraegliche Neubewertung dieser Versuche. Nur die markierte Testinstallation
darf verwendet werden; PVC-Aufbewahrung beim Skalieren muss Retain sein.
Nach Verschwinden des Datenbank-Pods wird eine Stimme abgegeben. Beide
Result-Pods muessen direkt ueber Loopback /readyz mit 503 antworten und
Datenbankfehler protokollieren; auch Worker muss einen Wiederverbindungsfehler
zeigen. Erst danach wird PostgreSQL wieder auf eine Replik gesetzt, auch bei
einem Beobachtungsfehler. Fehler beim Wiederherstellen sind ERROR und erfordern
manuelle Kontrolle des Testnamespaces. Anschliessend prueft T2 Daten,
Speicherzuordnung, neue PostgreSQL-UID, unveraenderte Result-/Worker-Prozesse,
Readiness 200 und Fachfunktion. Das ist kein Test einer Datenmigration.

Die isolierten Werkzeug-Regressionen laufen mit:

```sh
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
node --test scripts/tests/check-result.test.cjs
```

Der Browsercheck benoetigt Playwright, Chromium und installierte
Result-Abhaengigkeiten. Bei einem vorhandenen Browser kann dessen Pfad ueber
PLAYWRIGHT_CHROMIUM_EXECUTABLE gesetzt werden. Die Socket.IO-Testfixture
prueft das Testwerkzeug, nicht die gesamte Anwendung und keinen Cluster.
Die Python-Suite prueft die Monitoring-Ausdruecke mit Terraform in einem
providerfreien temporaeren Verzeichnis unter abweichenden Namespace-Namen.
