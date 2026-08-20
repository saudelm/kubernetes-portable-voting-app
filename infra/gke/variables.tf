variable "project_id" {
  description = "Google-Cloud-Projekt, in dem der Cluster erzeugt wird."
  type        = string
}

variable "location" {
  description = "Region oder Zone des Clusters (Zone haelt die Knotenzahl klein)."
  type        = string
  default     = "europe-west3-a"
}

variable "cluster_name" {
  description = "Name des GKE-Clusters."
  type        = string
  default     = "portable-voting"
}

variable "node_count" {
  description = "Anzahl der Knoten im separaten Node Pool."
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Maschinentyp der Worker Nodes."
  type        = string
  default     = "e2-standard-2"
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
  description = "Password used by the Postgres Helm secret."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.postgres_password) >= 16
    error_message = "postgres_password muss mindestens 16 Zeichen lang sein."
  }
}

variable "grafana_admin_password" {
  description = "Grafana admin password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 16
    error_message = "grafana_admin_password muss mindestens 16 Zeichen lang sein."
  }
}

variable "image_tag" {
  description = "Unveraenderlicher Commit-SHA-Tag der drei Anwendungsimages."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{7,40}$", var.image_tag))
    error_message = "image_tag muss ein Git-Commit-SHA mit 7 bis 40 Hex-Zeichen sein."
  }
}

variable "image_repository_base" {
  description = "Gemeinsamer GHCR-Pfad ohne Komponentenname, zum Beispiel ghcr.io/owner/repository."
  type        = string
  default     = "ghcr.io/saudelm/kubernetes-portable-voting-app"

  validation {
    condition     = can(regex("^ghcr\\.io/[a-z0-9_.-]+/[a-z0-9_.-]+$", var.image_repository_base))
    error_message = "image_repository_base muss die Form ghcr.io/owner/repository haben."
  }
}

variable "ghcr_username" {
  description = "GitHub-Benutzername fuer den privaten GHCR-Lesezugriff."
  type        = string
  default     = "saudelm"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.ghcr_username))
    error_message = "ghcr_username darf nur Buchstaben, Zahlen und Bindestriche enthalten."
  }
}

variable "image_pull_secret_name" {
  description = "Name des ausserhalb des Terraform-States erzeugten GHCR-Pull-Secrets."
  type        = string
  default     = "ghcr-pull"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.image_pull_secret_name))
    error_message = "image_pull_secret_name muss ein gueltiger Kubernetes-Name sein."
  }
}
