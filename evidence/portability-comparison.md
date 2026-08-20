# Statische Portabilitaetsanalyse

Erzeugt (UTC): `2026-08-20T10:46:46Z`

> Diese Auswertung vergleicht gerenderte Manifeste. Sie ist kein Nachweis einer erfolgreichen Laufzeitbereitstellung.

## Kennzahlen

| Kennzahl | Wert |
|---|---:|
| Objekte lokal | 35 |
| Objekte GKE | 35 |
| Identische Objektidentitaeten | 35 |
| Objektwiederverwendung | 100.00% |
| Wiederverwendete Blattwerte | 98.21% |
| Erwartete Umgebungsunterschiede | 11 |
| Unerwartete Unterschiede | 0 |

## Umgebungsunterschiede

| Objekt | Feld | Kategorie | Lokal | GKE |
|---|---|---|---|---|
| `Deployment/voting/voting-voting-app-result` | `spec.replicas` | replica_count | `1` | `2` |
| `Deployment/voting/voting-voting-app-result` | `spec.template.spec.containers[0].image` | image_reference | `"voting-result:local"` | `"ghcr.io/saudelm/kubernetes-portable-voting-app/result:abcdef1"` |
| `Deployment/voting/voting-voting-app-vote` | `spec.replicas` | replica_count | `1` | `2` |
| `Deployment/voting/voting-voting-app-vote` | `spec.template.spec.containers[0].image` | image_reference | `"voting-vote:local"` | `"ghcr.io/saudelm/kubernetes-portable-voting-app/vote:abcdef1"` |
| `Deployment/voting/voting-voting-app-worker` | `spec.template.spec.containers[0].image` | image_reference | `"voting-worker:local"` | `"ghcr.io/saudelm/kubernetes-portable-voting-app/worker:abcdef1"` |
| `Ingress/voting/voting-voting-app` | `spec.rules[0].host` | external_hostname | `"vote.127.0.0.1.nip.io"` | `"vote.192.0.2.1.nip.io"` |
| `Ingress/voting/voting-voting-app` | `spec.rules[1].host` | external_hostname | `"result.127.0.0.1.nip.io"` | `"result.192.0.2.1.nip.io"` |
| `NetworkPolicy/voting/voting-voting-app-allow-dns` | `spec.egress[0].to[1].namespaceSelector.matchLabels.kubernetes.io/metadata.name` | platform_networking | `"<absent>"` | `"kube-system"` |
| `NetworkPolicy/voting/voting-voting-app-allow-dns` | `spec.egress[0].to[1].podSelector.matchLabels.k8s-app` | platform_networking | `"<absent>"` | `"node-local-dns"` |
| `NetworkPolicy/voting/voting-voting-app-allow-ingress-to-web` | `spec.ingress[0].from[1].ipBlock.cidr` | platform_networking | `"<absent>"` | `"169.254.4.6/32"` |
| `StatefulSet/voting/voting-voting-app-postgres` | `spec.volumeClaimTemplates[0].spec.storageClassName` | storage_class | `"<absent>"` | `"standard-rwo"` |

## Interpretation

Die Objektidentitaeten muessen vollstaendig uebereinstimmen. Abweichungen sind nur fuer Replikate, Image-Referenzen, externe Hostnamen, die StorageClass und explizite Plattform-Netzwerkregeln vorgesehen. Ein Laufzeitnachweis fuer K3d und GKE wird getrennt erhoben.
