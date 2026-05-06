# GitOps Extension

GitOps is intentionally documented as an extension and not implemented in v1.

## Possible Approach

- Keep the Helm chart in this repository.
- Build images in CI and publish them to GHCR.
- Store environment-specific Helm values in Git.
- Let Argo CD or Flux reconcile the app into the cluster.

## Why It Is Not In v1

The current project focuses on local reproducibility with Windows, k3d, Helm and Terraform. Adding GitOps would introduce another controller, repository structure and operational workflow. For the bachelor thesis, it is enough to discuss GitOps as the next management layer after the Terraform and Helm baseline.

## Thesis Argument

GitOps strengthens portability because the desired state is stored in Git and can be reconciled into different clusters. It does not remove portability problems around storage classes, ingress implementations, registry access, secrets and stateful services.
