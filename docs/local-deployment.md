# Lokale Installation: Demo und Evaluation trennen

## Bestehende Demo ansehen

Diese Befehle lesen nur den expliziten Demo-Kontext:

```bash
kubectl --context k3d-portable-voting get nodes -o wide
kubectl --context k3d-portable-voting -n voting get pods -o wide
kubectl --context k3d-portable-voting -n voting get pvc
helm --kube-context k3d-portable-voting -n voting list
```

Der aktuelle gemeinsame Sollwert sind zwei Vote- und zwei Result-Pods sowie
je ein Worker-, Redis- und PostgreSQL-Pod. Die historische Fuenf-Pod-Installation
wird nicht nachtraeglich als Sieben-Pod-Test ausgegeben.

## Eine neue Demo aufbauen

Nur bei einem bewusst gewaehlten Neuaufbau die Schnellstartschritte der README
verwenden. Kennwoerter muessen extern gesetzt werden. Ein Apply gegen die
bestehende Demo kann deren Installation aendern und gehoert nicht zum Testplan.

## Wissenschaftliche Versuche

Die frueher hier gezeigten Pod-Loeschbefehle im Namespace voting und der
Exitcode-basierte Netzwerktest sind fuer die neue Evaluation ersetzt.
Verwende ausschliesslich `docs/evaluation-runbook.md` und den gemeinsamen Runner.

Der lokale Test verwendet einen separaten K3d-Cluster `voting-test-*`,
einen markierten Namespace, eigene PVCs, eigene Hostnamen und einen freien Port.
Kubeconfig und Terraform-State werden separat gespeichert.
Kein Testskript darf den Demo-Cluster, dessen Volumes oder dessen Kennwoerter
als Ersatz verwenden.

Vor dem Aufbau Docker-RAM und freie Kapazitaet pruefen. Wenn Demo und
vollstaendige Testumgebung nicht gleichzeitig passen, den Test nicht starten.
Eine RAM-Erhoehung mit Docker-Neustart benoetigt eine gesonderte Zustimmung.
