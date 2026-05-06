locals {
  vote_url    = "http://vote.127.0.0.1.nip.io:8080"
  result_url  = "http://result.127.0.0.1.nip.io:8080"
  grafana_url = "http://grafana.127.0.0.1.nip.io:8080"
}

resource "kubernetes_namespace_v1" "ingress_nginx" {
  metadata {
    name = var.ingress_namespace
  }
}

resource "kubernetes_namespace_v1" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name = var.monitoring_namespace
  }
}

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.15.1"
  namespace  = kubernetes_namespace_v1.ingress_nginx.metadata[0].name

  wait    = true
  timeout = 900

  values = [
    yamlencode({
      controller = {
        ingressClassResource = {
          name    = "nginx"
          enabled = true
          default = true
        }
        watchIngressWithoutClass = true
        service = {
          type = "LoadBalancer"
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.ingress_nginx]
}

resource "helm_release" "voting_app" {
  name      = "voting"
  chart     = "${path.module}/../../charts/voting-app"
  namespace = kubernetes_namespace_v1.app.metadata[0].name

  wait    = true
  timeout = 900

  values = [
    yamlencode({
      postgres = {
        password = var.postgres_password
      }
    })
  ]

  depends_on = [
    helm_release.ingress_nginx,
    kubernetes_namespace_v1.app
  ]
}

resource "helm_release" "prometheus" {
  count = var.enable_monitoring ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "29.6.0"
  namespace  = kubernetes_namespace_v1.monitoring[0].metadata[0].name

  wait    = true
  timeout = 900

  values = [
    yamlencode({
      alertmanager = {
        enabled = false
      }
      "prometheus-pushgateway" = {
        enabled = false
      }
      server = {
        persistentVolume = {
          enabled = false
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "768Mi"
          }
        }
      }
      "kube-state-metrics" = {
        enabled = true
      }
      "prometheus-node-exporter" = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.monitoring]
}

resource "helm_release" "grafana" {
  count = var.enable_monitoring ? 1 : 0

  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "10.5.15"
  namespace  = kubernetes_namespace_v1.monitoring[0].metadata[0].name

  wait    = true
  timeout = 900

  values = [
    yamlencode({
      adminUser     = "admin"
      adminPassword = var.grafana_admin_password
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        hosts            = ["grafana.127.0.0.1.nip.io"]
      }
      persistence = {
        enabled = false
      }
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://prometheus-server.monitoring.svc.cluster.local"
              access    = "proxy"
              isDefault = true
            }
          ]
        }
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    })
  ]

  depends_on = [
    helm_release.ingress_nginx,
    helm_release.prometheus
  ]
}
