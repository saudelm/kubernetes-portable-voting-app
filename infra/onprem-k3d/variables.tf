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

variable "app_namespace" {
  description = "Namespace for the voting application."
  type        = string
  default     = "voting"
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
  default     = "postgres"
}

variable "grafana_admin_password" {
  description = "Local lab Grafana admin password."
  type        = string
  sensitive   = true
  default     = "admin"
}
