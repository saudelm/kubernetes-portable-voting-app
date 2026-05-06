# Kubernetes Portable Voting App

Windows-first adaptation of the Docker example voting app for a portable, on-prem-like Kubernetes management environment.

The project supports a bachelor thesis topic around Kubernetes as a foundation for portable container-centered management. It demonstrates local multi-node Kubernetes with k3d/k3s, local image builds, Helm-based application packaging, Terraform-managed add-ons, Prometheus/Grafana monitoring and a security baseline.

## Architecture

- Kubernetes: k3d/k3s multi-node cluster with 1 server and 2 agents
- Ingress: ingress-nginx installed by Terraform, Traefik disabled
- App packaging: Helm chart in `charts/voting-app`
- Infrastructure/add-ons: Terraform in `infra/onprem-k3d`
- Monitoring: lightweight Prometheus and Grafana Helm releases
- Security baseline: Pod Security labels, non-root containers, RBAC, ServiceAccounts, NetworkPolicies
- Stateful workload: Postgres StatefulSet with PVC

Local URLs:

- Vote: `http://vote.127.0.0.1.nip.io:8080`
- Result: `http://result.127.0.0.1.nip.io:8080`
- Grafana: `http://grafana.127.0.0.1.nip.io:8080`

## Windows Quickstart

Open PowerShell in the repository root:

```powershell
cd "C:\Users\sauda\Documents\Codex\2026-05-06\ja-bei-helm-release-monitoring-0\kubernetes-portable-voting-app"
```

Install portable tools into `.local\bin`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-tools.ps1
```

Start Docker Desktop before creating the cluster. Then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tools-check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cluster-up.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-local.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tf-init.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tf-apply.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pods.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\urls.ps1
```

`make` targets are provided as optional shortcuts for environments that have `make` available.

## Validation

Run static validation without requiring a live cluster:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Equivalent commands:

```powershell
.\.local\bin\helm.exe lint .\charts\voting-app
.\.local\bin\helm.exe template voting .\charts\voting-app --namespace voting
.\.local\bin\terraform.exe -chdir="infra\onprem-k3d" fmt -check
.\.local\bin\terraform.exe -chdir="infra\onprem-k3d" init -backend=false
.\.local\bin\terraform.exe -chdir="infra\onprem-k3d" validate
```

## GitHub And GHCR

The original DockerSamples remote is kept as `upstream`. Do not push to it.

The intended private repository is:

```text
saudelm/kubernetes-portable-voting-app
```

After `gh auth login`, push with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\github-push.ps1
```

CI builds the three application images and publishes them to GHCR on pushes to `main`:

- `ghcr.io/saudelm/kubernetes-portable-voting-app/vote`
- `ghcr.io/saudelm/kubernetes-portable-voting-app/result`
- `ghcr.io/saudelm/kubernetes-portable-voting-app/worker`

The local Helm values default to local images (`voting-vote:local`, `voting-result:local`, `voting-worker:local`) so the Windows demo works before GHCR is configured.

## Thesis Notes

- k3d/k3s is closer to on-prem and edge Kubernetes than Minikube, but it is still a local simulation.
- Helm values demonstrate parameterization and deployment portability.
- Terraform makes cluster add-ons and the app deployment reproducible.
- Stateful workloads remain the hardest part of portability. This demo uses a Postgres PVC, but it is not highly available.
- GitOps is documented as an extension, not implemented in v1.

See:

- `docs/architecture.md`
- `docs/security.md`
- `docs/gitops.md`
- `docs/portability-evaluation.md`
