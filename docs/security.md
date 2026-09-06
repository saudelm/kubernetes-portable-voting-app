# Sicherheitsbasis

## Umgesetzte Kontrollen

- Der Namespace `voting` erzwingt das Pod-Security-Profil `restricted` und setzt es zusaetzlich fuer Audit und Warnung.
- Die drei Anwendungsimages laufen mit festen Non-Root-IDs und lauschen auf Port `8080`.
- `allowPrivilegeEscalation` ist deaktiviert; Linux-Capabilities werden entfernt; `RuntimeDefault`-Seccomp ist gesetzt.
- Jeder Workload besitzt einen eigenen ServiceAccount; API-Tokens werden nicht automatisch eingebunden.
- Leere, workloadbezogene RBAC-Rollen machen den fehlenden Kubernetes-API-Bedarf explizit.
- Eine Default-Deny-NetworkPolicy sperrt Ingress und Egress im Anwendungsnamespace.
- Freigegeben sind nur DNS, Traefik zu Vote/Result, Vote zu Redis, Worker zu Redis/PostgreSQL und Result zu PostgreSQL.
- GKE verlangt einen Commit-SHA-Image-Tag und mindestens 16 Zeichen lange PostgreSQL- und Grafana-Kennwoerter.
- Node-Abhaengigkeiten sind exakt gesperrt. Der Audit ist eine zeitgebundene Pruefung; sein konkretes Ergebnis gehoert zum jeweiligen Testprotokoll.
- Die Browseroberflaechen laden keine externen Skripte; Vote akzeptiert nur `a` oder `b` und setzt die anonyme Kennung mit `HttpOnly` und `SameSite=Lax`.
- Die Anwendungsversionen sind im Repository dokumentiert. Supportstatus und neue Sicherheitsbefunde muessen zum jeweiligen Einsatzzeitpunkt erneut geprueft werden.

## Geheimnisse

Das Helm-Chart erzeugt ein Kubernetes Secret. Terraform uebergibt die Werte und kann sie deshalb im State speichern. Der State darf nicht in Git gelangen und muss wie ein Geheimnis behandelt werden. Fuer den Hochschulprototyp werden Kennwoerter ueber `TF_VAR_...`-Umgebungsvariablen gesetzt. Eine produktive Plattform sollte einen Secret Manager und ein Verfahren zur Rotation einsetzen.

## Bekannte Grenzen

- Neue lokale und Cloud-Installationen verlangen extern gesetzte Kennwoerter. Die Aenderung rotiert keine bereits verwendeten Demo-Zugangsdaten.
- TLS ist fuer die nip.io-Experimenthosts nicht eingerichtet.
- Images sind auf Versionsebene markiert, aber nicht per Digest im Deployment fixiert.
- Es gibt noch keine Signaturpruefung, Admission Policy, SBOM-Auswertung oder automatisierte Container-Registry-Policy.
- PostgreSQL besitzt weder Backupautomation noch Verschluesselungsschluesselverwaltung durch den Prototyp.
- Redis ist eine fluechtige Warteschlange; ein Redis-Pod-Verlust kann noch nicht verarbeitete Stimmen entfernen.
- NetworkPolicies sind nur wirksam, wenn das jeweilige CNI sie durchsetzt; lokal und auf GKE muss dies getestet werden.

## Produktionsrichtung

Fuer Produktion waeren mindestens kontrolliertes DNS und TLS, private Registry-Zugriffe, Secret Manager, Image-Digests und Signaturpruefung, Security-Scanning, Backup/Restore-Tests, Audit-Logging, Policy-as-Code sowie ein hochverfuegbares Datenbankkonzept erforderlich.
