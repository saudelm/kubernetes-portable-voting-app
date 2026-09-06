# Architektur

## Ziel

Der Prototyp demonstriert eine portierbare Managementumgebung fuer eine kleine Mehrkomponentenanwendung. Die Vergleichsziele sind ein lokaler, On-Premise-naher K3d/K3s-Cluster und ein verwalteter GKE-Cluster. Die zentrale Designregel lautet: Anwendungsartefakte bleiben gemeinsam, Zielumgebungsdetails werden als explizite Parameter oder Infrastrukturmodule gekapselt.

## Schichten

1. **Anwendung:** `vote`, `redis`, `worker`, `postgres` und `result`.
2. **Container:** OCI-Images mit Non-Root-Laufzeit und festen Anwendungsports.
3. **Orchestrierung:** Standardobjekte wie Deployment, StatefulSet, Service, Ingress, ConfigMap, Secret, ServiceAccount und NetworkPolicy.
4. **Paketierung:** ein gemeinsames Helm-Chart mit lokalen und GKE-spezifischen Values.
5. **Plattformautomatisierung:** getrennte Terraform-Root-Module fuer K3d und GKE.
6. **Betrieb:** Traefik, Prometheus und Grafana als versionierte Helm-Releases.

## Lokale Umgebung

- K3d erzeugt einen K3s-Cluster mit einem Server und zwei Agenten.
- Der in K3s enthaltene Traefik wird bei der Clustererzeugung deaktiviert.
- Terraform installiert eine explizit versionierte Traefik-Version, Anwendung und Monitoring.
- Der K3d-Load-Balancer bildet HTTP auf Host-Port `8080` und HTTPS auf `8443` ab.
- Die historische Demo verwendet importierte `:local`-Images. Neue Tests verwenden separate, revisions- und architekturbezogene Images mit dokumentierten Digests.
- Fuer PostgreSQL wird `local-path` verwendet. Der isolierte Testcluster hat eigene Volumes und einen freien HTTP-Port, nicht die Demo-Ports.
- Vote und Result laufen im gemeinsamen Vergleichsprofil mit je zwei Pods, Worker, Redis und PostgreSQL je einfach. Die historische lokale Installation hatte fuenf Pods.

## GKE-Umgebung

- Terraform aktiviert Compute Engine API und Kubernetes Engine API.
- Ein zonaler GKE-Standardcluster und ein separater Node Pool werden erzeugt.
- GKE Dataplane V2 setzt die NetworkPolicies durch.
- Eine regionale statische IP wird vor dem Ingress-Controller reserviert.
- Traefik erhaelt diese IP als `loadBalancerIP`; Vote-, Result- und Grafana-Hosts werden daraus abgeleitet.
- Ein Commit-SHA-Tag benennt den Build, ist aber nicht unveraenderlich. Erst Build-Digests und tatsaechlich ausgefuehrte Image-IDs belegen den Inhalt. Historische GKE-Images gehoeren nicht automatisch zum aktuellen Quellstand.
- PostgreSQL verwendet die GKE-StorageClass `standard-rwo`.
- Vote und Result laufen wie lokal je zweifach. Das ist eine gemeinsame Versuchsentscheidung, keine GKE-, Load-Balancer- oder Sicherheitsanforderung.

Der beschriebene Infrastrukturaufbau ist historisch. Neue GKE-Tests duerfen nur nach gesonderter Freigabe in isolierten Namespaces und eigenen PVCs des vorhandenen Clusters laufen. Das GKE-Terraform-Modul wird dafuer nicht erneut angewendet; keine neuen Cluster, Node Pools oder Lastverteiler und kein Konto-Upgrade.

## Anwendungspfad

1. `vote` nimmt eine Stimme an und schreibt sie in Redis.
2. `worker` liest aus Redis und schreibt den Datensatz nach PostgreSQL.
3. `result` fragt PostgreSQL ab und aktualisiert die Anzeige ueber Socket.IO.
4. Vote und Result sind ueber Traefik erreichbar; Redis bleibt ueber ClusterIP intern, PostgreSQL ueber einen internen Headless Service.
5. Result versucht fehlgeschlagene Datenbankabfragen erneut; seine Readiness bleibt bis zur erfolgreichen Abfrage negativ. Worker verbindet sich nach einem Datenbankabbruch wieder und haelt eine bereits entnommene Stimme bis zum erfolgreichen UPSERT im Prozessspeicher.

## Portabilitaetsmechanismen

- Container kapseln Laufzeitabhaengigkeiten.
- Kubernetes-Standardobjekte beschreiben den gemeinsamen Sollzustand.
- Helm parametrisiert Registry, Tag, Replikate, Hosts und StorageClass.
- Terraform beschreibt Infrastruktur und Plattformdienste; ein Plan ist kein Laufzeitnachweis.
- Die statische Analyse vergleicht beide Helm-Renderings auf Objekt- und Feldebene.
- Der gemeinsame Runner prueft Fachfunktion, Volume-Erhalt, Pod-Ersatz und kontrollierte Netzisolation dreimal je Ziel. Implementierung und Unit-Tests sind kein Ersatz fuer noch ausstehende Clusterlaeufe; siehe `evaluation-runbook.md`.

## Bewusste Grenzen

Der Prototyp untersucht ausschliesslich hostbasiertes HTTP-Routing ueber die Kubernetes-Ingress-API und Traefik. Produktives DNS und TLS sind nicht Bestandteil der Evaluation.

Datenmigration ist ausdruecklich nicht Teil der Untersuchung. Das gemeinsame StatefulSet beschreibt die Bereitstellung; T2 untersucht den Erhalt von Testdaten auf demselben Volume nach Pod-Ersatz. Daraus folgt weder ein Datenumzug noch Hochverfuegbarkeit oder Backup/Restore zwischen Clustern.

Die zwei Web-Replikate je Ziel belegen daher keine vollstaendige Hochverfuegbarkeit: Es gibt keine garantierte Verteilung auf unterschiedliche Knoten, und PostgreSQL bleibt eine einzelne Instanz.

Redis ist bewusst nur eine fluechtige Warteschlange mit `emptyDir`. PostgreSQL ist
das System of Record; noch nicht durch den Worker verarbeitete Stimmen koennen bei
einem Redis-Pod-Verlust trotzdem verloren gehen. Fuer Produktion waeren eine
persistente Queue oder ein belastbares Acknowledgement-Verfahren erforderlich.
