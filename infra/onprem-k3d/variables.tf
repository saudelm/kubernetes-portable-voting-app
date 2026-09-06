variable "kubeconfig_path" {
  description = "Path to the kubeconfig used by kubectl, Helm and Terraform."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context created by scripts/cluster-up.ps1."
  type        = string
  default     = "k3d-portable-voting"
}

variable "http_port" {
  description = "Host port mapped to the local ingress load balancer."
  type        = number
  default     = 8080
}

variable "host_suffix" {
  description = "Use a distinct suffix for isolated test installations."
  type        = string
  default     = "127.0.0.1.nip.io"
}

variable "image_tag" {
  description = "Locally imported image tag; evaluation uses the full build-specific tag."
  type        = string
  default     = "local"
}

variable "image_repositories" {
  type = map(string)
  default = {
    vote   = "voting-vote"
    result = "voting-result"
    worker = "voting-worker"
  }
}

variable "app_namespace" {
  description = "Namespace for the voting application."
  type        = string
  default     = "voting"
}

variable "app_release" {
  type    = string
  default = "voting"
}

variable "isolated_test" {
  description = "Mark a newly created namespace as an isolated test target."
  type        = bool
  default     = false
  validation {
    condition     = !var.isolated_test || startswith(var.app_namespace, "voting-test-")
    error_message = "Isolated tests require a voting-test-* namespace."
  }
}

variable "ingress_namespace" {
  description = "Namespace for the Traefik ingress controller."
  type        = string
  default     = "traefik"
}

variable "monitoring_namespace" {
  description = "Namespace for Prometheus and Grafana."
  type        = string
  default     = "monitoring"
}

variable "enable_monitoring" {
  description = "Install lightweight Prometheus and Grafana releases."
  type        = bool
  default     = true
}

variable "postgres_password" {
  description = "Local lab password used by the Postgres Helm secret."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.postgres_password) >= 16
    error_message = "postgres_password must contain at least 16 characters."
  }
}

variable "grafana_admin_password" {
  description = "Local lab Grafana admin password."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.grafana_admin_password) >= 16
    error_message = "grafana_admin_password must contain at least 16 characters."
  }
}
