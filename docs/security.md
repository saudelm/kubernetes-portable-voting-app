# Security Baseline

## Implemented Controls

- The `voting` namespace uses Pod Security Admission labels with `restricted` for enforce, audit and warn.
- Application containers run as non-root users and listen on unprivileged port `8080`.
- ServiceAccount tokens are not mounted into pods.
- Each workload has its own ServiceAccount.
- RBAC roles are intentionally empty and bound per workload to make least privilege explicit.
- Container security contexts drop Linux capabilities and disable privilege escalation.
- NetworkPolicies default-deny ingress and egress in the application namespace.
- Only required traffic paths are allowed:
  - vote to Redis
  - worker to Redis and Postgres
  - result to Postgres
  - ingress-nginx to vote and result
  - application pods to kube-dns

## Known Limits

- The local Postgres password is intentionally simple for reproducible local demos.
- Terraform state may contain generated or supplied secret values and must not be committed.
- The original result app dependencies may report npm vulnerabilities. They are documented as inherited application risk and are not blindly upgraded because the project focus is infrastructure portability.
- TLS is not configured for the local nip.io demo hostnames.

## Production Direction

A production environment would require a proper secret manager, image signing or provenance checks, stronger vulnerability management, TLS certificates, backup/restore testing and a production-grade database design.
