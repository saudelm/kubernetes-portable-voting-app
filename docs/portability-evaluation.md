# Portability Evaluation

## What Is Portable

- The application is split into container images.
- Kubernetes manifests are generated through Helm and can be parameterized.
- Terraform can reproduce namespaces and add-ons.
- ingress-nginx, Prometheus and Grafana are installed as standard Helm charts.
- The app avoids hardcoded service names in source code and uses environment variables.

## What Is Environment-Specific

- k3d host port mappings are local to Docker Desktop.
- nip.io hostnames are convenient for local demos, not a production DNS model.
- Storage behavior depends on the cluster storage class.
- NetworkPolicy enforcement depends on the CNI implementation.
- GHCR access requires credentials in non-public environments.

## Stateful Workload Limits

Postgres uses a PVC instead of `emptyDir`, so data survives pod restarts. This is more realistic than the original demo. It is still not highly available:

- one database replica
- no automated backups
- no failover
- no cross-cluster migration process

This is a useful thesis point: stateless services are comparatively portable, while stateful services require storage, backup, restore and operational decisions that are tied to the target environment.

## Conclusion

k3d/k3s is a good local proxy for an on-prem or edge-style Kubernetes environment. It is not a substitute for production validation on real infrastructure. The project should be presented as a reproducible demonstration environment and as a basis for discussing the boundaries of Kubernetes portability.
