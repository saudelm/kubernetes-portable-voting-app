# Architecture

## Goal

The project demonstrates a portable, container-centered management environment for a small multi-service application. The local target is Windows with Docker Desktop and k3d/k3s.

## Runtime Model

- k3d creates a k3s cluster with one server node and two agent nodes.
- Traefik is disabled to avoid hidden defaults and to keep ingress-nginx managed by Terraform.
- Host ports are mapped through the k3d load balancer:
  - HTTP: `8080`
  - HTTPS: `8443`
- Terraform installs namespaces, ingress-nginx, the app Helm chart, Prometheus and Grafana.

## Application Model

The voting app has five runtime components:

- `vote`: Flask UI that writes votes into Redis
- `redis`: queue for incoming votes
- `worker`: .NET worker that reads Redis and writes Postgres
- `postgres`: persistent database in a StatefulSet with a PVC
- `result`: Node.js UI that reads aggregated vote counts from Postgres

All services are internal `ClusterIP` services. External access goes through ingress-nginx.

## Portability Mechanisms

- Docker images isolate runtime dependencies.
- Helm packages the Kubernetes objects as a reusable chart.
- Helm values expose image names, tags, hosts and app options.
- Terraform reproduces add-ons and namespaces.
- k3d/k3s provides a local multi-node target that is closer to edge or on-prem scenarios than single-node Minikube.
