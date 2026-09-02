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
- Lokale Images werden in den Cluster importiert und tragen den Tag `local`.
- Fuer PostgreSQL greift die Standard-StorageClass des Clusters.
- Vote und Result laufen mit je einem Pod als ressourcenschonende lokale Funktionsreferenz.

## GKE-Umgebung

- Terraform aktiviert Compute Engine API und Kubernetes Engine API.
- Ein zonaler GKE-Standardcluster und ein separater Node Pool werden erzeugt.
- GKE Dataplane V2 setzt die NetworkPolicies durch.
- Eine regionale statische IP wird vor dem Ingress-Controller reserviert.
- Traefik erhaelt diese IP als `loadBalancerIP`; Vote-, Result- und Grafana-Hosts werden daraus abgeleitet.
- Die Anwendung verwendet unveraenderliche GHCR-Images mit demselben Commit-SHA.
- PostgreSQL verwendet die GKE-StorageClass `standard-rwo`.
- Vote und Result laufen mit je zwei Pods, um Verteilung und Wiederherstellung des Sollzustands zu pruefen; die uebrigen Komponenten bleiben einfach ausgefuehrt.

## Anwendungspfad

1. `vote` nimmt eine Stimme an und schreibt sie in Redis.
2. `worker` liest aus Redis und schreibt den Datensatz nach PostgreSQL.
3. `result` fragt PostgreSQL ab und aktualisiert die Anzeige ueber Socket.IO.
4. Vote und Result sind ueber Traefik erreichbar; die Datenkomponenten bleiben als `ClusterIP` intern.

## Portabilitaetsmechanismen

- Container kapseln Laufzeitabhaengigkeiten.
- Kubernetes-Standardobjekte beschreiben den gemeinsamen Sollzustand.
- Helm parametrisiert Registry, Tag, Replikate, Hosts und StorageClass.
- Terraform reproduziert Infrastruktur und Plattformdienste.
- Die statische Analyse vergleicht beide Helm-Renderings auf Objekt- und Feldebene.
- Laufzeittests pruefen Durchstich, Persistenz, Selbstheilung und Netzisolation getrennt je Zielumgebung.

## Bewusste Grenzen

Der Prototyp untersucht ausschliesslich hostbasiertes HTTP-Routing ueber die Kubernetes-Ingress-API und Traefik. Produktives DNS und TLS sind nicht Bestandteil der Evaluation.

Stateful Portability ist nur teilweise erreicht. Das gemeinsame StatefulSet ist portierbar, das Persistenzmedium und ein belastbarer Migrationsweg sind es nicht automatisch. Der Prototyp enthaelt weder Hochverfuegbarkeit noch Backup/Restore zwischen Clustern.

Die zwei Web-Replikate in GKE belegen daher keine vollstaendige Hochverfuegbarkeit: Es gibt keine garantierte Verteilung auf unterschiedliche Knoten, und PostgreSQL bleibt eine einzelne Instanz.

Redis ist bewusst nur eine fluechtige Warteschlange mit `emptyDir`. PostgreSQL ist
das System of Record; noch nicht durch den Worker verarbeitete Stimmen koennen bei
einem Redis-Pod-Verlust trotzdem verloren gehen. Fuer Produktion waeren eine
persistente Queue oder ein belastbares Acknowledgement-Verfahren erforderlich.
