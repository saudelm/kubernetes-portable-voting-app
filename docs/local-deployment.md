# Lokale Durchfuehrung und Nachweisplan

Diese Anleitung erhebt die lokalen Laufzeitnachweise in derselben Struktur wie der
spaetere GKE-Versuch. K3d/K3s ist eine On-Premise-nahe Laborumgebung, kein Nachweis
fuer eine reale Unternehmensinfrastruktur.

## 1. Aufbau und Vorpruefung

Docker Desktop starten und im Projektstamm ausfuehren:

```bash
make tools-check
make validate
make local
kubectl get pods -n voting -o wide
```

Erwartung: je ein Ready-Pod fuer Vote, Result, Worker und Redis sowie
`voting-voting-app-postgres-0`. Die lokalen URLs zeigt `make urls`.

## 2. T1 - fachlicher Durchstich

1. `http://vote.127.0.0.1.nip.io:8080` mit sichtbarer Adresszeile oeffnen.
2. Eine Stimme abgeben.
3. `http://result.127.0.0.1.nip.io:8080` oeffnen.
4. Vote- und Result-Ansicht mit Zeitpunkt als getrennte Screenshots sichern.

Technische Kontrolle:

```bash
curl --fail --show-error http://vote.127.0.0.1.nip.io:8080/healthz
curl --fail --show-error http://result.127.0.0.1.nip.io:8080/healthz
```

Erfolg: Beide Health-Endpunkte antworten und die Stimme erscheint in Result.

## 3. T2 - Persistenz nach Pod-Ersatz

```bash
mkdir -p evidence/manual-local
kubectl exec -n voting voting-voting-app-postgres-0 -- \
  psql -U postgres -d postgres -Atc \
  "SELECT vote, count(*) FROM votes GROUP BY vote ORDER BY vote" \
  > evidence/manual-local/t2-before.txt

kubectl delete pod -n voting voting-voting-app-postgres-0
kubectl wait -n voting --for=condition=Ready \
  pod/voting-voting-app-postgres-0 --timeout=300s

kubectl exec -n voting voting-voting-app-postgres-0 -- \
  psql -U postgres -d postgres -Atc \
  "SELECT vote, count(*) FROM votes GROUP BY vote ORDER BY vote" \
  > evidence/manual-local/t2-after.txt

diff -u evidence/manual-local/t2-before.txt evidence/manual-local/t2-after.txt
```

Erfolg: `diff` zeigt keine Aenderung. Das prueft den Pod-Ersatz mit bestehendem
Volume, aber weder Backup noch clusteruebergreifende Wiederherstellung.

## 4. T3 - Selbstheilung

```bash
kubectl get pods -n voting -l app.kubernetes.io/component=vote \
  -o custom-columns=NAME:.metadata.name,UID:.metadata.uid \
  > evidence/manual-local/t3-before.txt

kubectl delete pod -n voting -l app.kubernetes.io/component=vote
kubectl rollout status -n voting deployment/voting-voting-app-vote --timeout=300s
kubectl wait -n voting --for=condition=Ready pod \
  -l app.kubernetes.io/component=vote --timeout=300s

kubectl get pods -n voting -l app.kubernetes.io/component=vote \
  -o custom-columns=NAME:.metadata.name,UID:.metadata.uid \
  > evidence/manual-local/t3-after.txt

cat evidence/manual-local/t3-before.txt
cat evidence/manual-local/t3-after.txt
```

Erfolg: Der lokale Vote-Pod besitzt eine neue UID und ist wieder Ready. In GKE sind
wegen der dortigen Werte zwei Vote-Replikate zu erwarten.

## 5. T4 - NetworkPolicy

Erlaubten Weg zu Redis pruefen:

```bash
kubectl exec -n voting deploy/voting-voting-app-vote -- python -c \
  'import socket; s=socket.create_connection(("voting-voting-app-redis",6379),3); print("redis reachable"); s.close()'
```

Gesperrten Weg zu PostgreSQL pruefen:

```bash
if kubectl exec -n voting deploy/voting-voting-app-vote -- python -c \
  'import socket; socket.create_connection(("voting-voting-app-postgres",5432),3)'; then
  echo "FEHLER: PostgreSQL war vom Vote-Pod erreichbar"
else
  echo "ERWARTET: PostgreSQL-Verbindung wurde blockiert"
fi
```

Erfolg: Redis ist erreichbar, PostgreSQL aus dem Vote-Pod nicht.

## 6. Nachweise sichern

```bash
./scripts/collect-evidence.sh local
```

Zusaetzlich die Dateien aus `evidence/manual-local/`, die Screenshots, das Datum,
die Zeitzone, den Commit-SHA und alle Abweichungen in die Ergebnisvorlage eintragen.
Fehlgeschlagene Tests nicht loeschen, sondern Ursache, Korrektur und Wiederholung
dokumentieren.
