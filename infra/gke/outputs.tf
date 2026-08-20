output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "location" {
  value = var.location
}

output "get_credentials_command" {
  description = "Verbindet kubectl mit dem erzeugten Cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --location ${var.location} --project ${var.project_id}"
}

output "ingress_ip" {
  description = "Reservierte regionale IP des Traefik-LoadBalancers."
  value       = google_compute_address.ingress.address
}

output "vote_url" {
  value = "http://${local.vote_host}"
}

output "result_url" {
  value = "http://${local.result_host}"
}

output "grafana_url" {
  value = var.enable_monitoring ? "http://${local.grafana_host}" : null
}

output "grafana_admin_user" {
  value = "admin"
}
