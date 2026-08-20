locals {
  gke_region   = length(split("-", var.location)) == 3 ? join("-", slice(split("-", var.location), 0, 2)) : var.location
  vote_host    = "vote.${google_compute_address.ingress.address}.nip.io"
  result_host  = "result.${google_compute_address.ingress.address}.nip.io"
  grafana_host = "grafana.${google_compute_address.ingress.address}.nip.io"

  grafana_portable_dashboard = {
    annotations = {
      list = []
    }
    editable             = true
    fiscalYearStartMonth = 0
    graphTooltip         = 0
    id                   = null
    links                = []
    liveNow              = false
    panels = [
      {
        datasource = {
          type = "prometheus"
          uid  = "Prometheus"
        }
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "red"
                  value = null
                },
                {
                  color = "green"
                  value = 1
                }
              ]
            }
            unit = "short"
          }
          overrides = []
        }
        gridPos = {
          h = 4
          w = 6
          x = 0
          y = 0
        }
        id = 1
        options = {
          colorMode   = "background"
          graphMode   = "area"
          justifyMode = "auto"
          orientation = "auto"
          reduceOptions = {
            calcs  = ["lastNotNull"]
            fields = ""
            values = false
          }
          textMode   = "auto"
          wideLayout = true
        }
        pluginVersion = "12.3.1"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid  = "Prometheus"
            }
            expr         = "sum(kube_pod_status_phase{namespace=\"voting\",phase=\"Running\"})"
            legendFormat = "running pods"
            refId        = "A"
          }
        ]
        title = "Voting Pods Running"
        type  = "stat"
      },
      {
        datasource = {
          type = "prometheus"
          uid  = "Prometheus"
        }
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "green"
                  value = null
                },
                {
                  color = "orange"
                  value = 1
                },
                {
                  color = "red"
                  value = 5
                }
              ]
            }
            unit = "short"
          }
          overrides = []
        }
        gridPos = {
          h = 4
          w = 6
          x = 6
          y = 0
        }
        id = 2
        options = {
          colorMode   = "background"
          graphMode   = "area"
          justifyMode = "auto"
          orientation = "auto"
          reduceOptions = {
            calcs  = ["lastNotNull"]
            fields = ""
            values = false
          }
          textMode   = "auto"
          wideLayout = true
        }
        pluginVersion = "12.3.1"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid  = "Prometheus"
            }
            expr         = "sum(kube_pod_container_status_restarts_total{namespace=\"voting\"})"
            legendFormat = "container restarts"
            refId        = "A"
          }
        ]
        title = "Voting Container Restarts"
        type  = "stat"
      },
      {
        datasource = {
          type = "prometheus"
          uid  = "Prometheus"
        }
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              axisBorderShow   = false
              axisCenteredZero = false
              axisColorMode    = "text"
              axisLabel        = ""
              axisPlacement    = "auto"
              barAlignment     = 0
              barWidthFactor   = 0.6
              drawStyle        = "line"
              fillOpacity      = 12
              gradientMode     = "none"
              hideFrom = {
                legend  = false
                tooltip = false
                viz     = false
              }
              insertNulls       = false
              lineInterpolation = "linear"
              lineWidth         = 2
              pointSize         = 5
              scaleDistribution = {
                type = "linear"
              }
              showPoints = "never"
              spanNulls  = false
              stacking = {
                group = "A"
                mode  = "none"
              }
              thresholdsStyle = {
                mode = "off"
              }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "green"
                  value = null
                }
              ]
            }
            unit = "cores"
          }
          overrides = []
        }
        gridPos = {
          h = 8
          w = 12
          x = 0
          y = 4
        }
        id = 3
        options = {
          legend = {
            calcs       = []
            displayMode = "list"
            placement   = "bottom"
            showLegend  = true
          }
          tooltip = {
            hideZeros = false
            mode      = "single"
            sort      = "none"
          }
        }
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid  = "Prometheus"
            }
            expr         = "sum by (pod) (rate(container_cpu_usage_seconds_total{namespace=\"voting\",pod!=\"\",container!=\"POD\",image!=\"\"}[5m]))"
            legendFormat = "{{pod}}"
            refId        = "A"
          }
        ]
        title = "Voting Pod CPU"
        type  = "timeseries"
      },
      {
        datasource = {
          type = "prometheus"
          uid  = "Prometheus"
        }
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              axisBorderShow   = false
              axisCenteredZero = false
              axisColorMode    = "text"
              axisLabel        = ""
              axisPlacement    = "auto"
              barAlignment     = 0
              barWidthFactor   = 0.6
              drawStyle        = "line"
              fillOpacity      = 12
              gradientMode     = "none"
              hideFrom = {
                legend  = false
                tooltip = false
                viz     = false
              }
              insertNulls       = false
              lineInterpolation = "linear"
              lineWidth         = 2
              pointSize         = 5
              scaleDistribution = {
                type = "linear"
              }
              showPoints = "never"
              spanNulls  = false
              stacking = {
                group = "A"
                mode  = "none"
              }
              thresholdsStyle = {
                mode = "off"
              }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "green"
                  value = null
                }
              ]
            }
            unit = "bytes"
          }
          overrides = []
        }
        gridPos = {
          h = 8
          w = 12
          x = 12
          y = 4
        }
        id = 4
        options = {
          legend = {
            calcs       = []
            displayMode = "list"
            placement   = "bottom"
            showLegend  = true
          }
          tooltip = {
            hideZeros = false
            mode      = "single"
            sort      = "none"
          }
        }
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid  = "Prometheus"
            }
            expr         = "sum by (pod) (container_memory_working_set_bytes{namespace=\"voting\",pod!=\"\",container!=\"POD\",image!=\"\"})"
            legendFormat = "{{pod}}"
            refId        = "A"
          }
        ]
        title = "Voting Pod Memory"
        type  = "timeseries"
      },
      {
        datasource = {
          type = "prometheus"
          uid  = "Prometheus"
        }
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              axisBorderShow   = false
              axisCenteredZero = false
              axisColorMode    = "text"
              axisLabel        = ""
              axisPlacement    = "auto"
              barAlignment     = 0
              barWidthFactor   = 0.6
              drawStyle        = "line"
              fillOpacity      = 8
              gradientMode     = "none"
              hideFrom = {
                legend  = false
                tooltip = false
                viz     = false
              }
              insertNulls       = false
              lineInterpolation = "linear"
              lineWidth         = 2
              pointSize         = 5
              scaleDistribution = {
                type = "linear"
              }
              showPoints = "never"
              spanNulls  = false
              stacking = {
                group = "A"
                mode  = "none"
              }
              thresholdsStyle = {
                mode = "off"
              }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "green"
                  value = null
                }
              ]
            }
            unit = "short"
          }
          overrides = []
        }
        gridPos = {
          h = 8
          w = 12
          x = 0
          y = 12
        }
        id = 5
        options = {
          legend = {
            calcs       = []
            displayMode = "list"
            placement   = "bottom"
            showLegend  = true
          }
          tooltip = {
            hideZeros = false
            mode      = "single"
            sort      = "none"
          }
        }
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid  = "Prometheus"
            }
            expr         = "sum by (deployment) (kube_deployment_status_replicas_available{namespace=\"voting\"})"
            legendFormat = "{{deployment}}"
            refId        = "A"
          }
        ]
        title = "Available Voting Deployment Replicas"
        type  = "timeseries"
      },
      {
        datasource = {
          type = "prometheus"
          uid  = "Prometheus"
        }
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            mappings = [
              {
                options = {
                  "0" = {
                    color = "red"
                    text  = "Down"
                  }
                  "1" = {
                    color = "green"
                    text  = "Up"
                  }
                }
                type = "value"
              }
            ]
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "red"
                  value = null
                },
                {
                  color = "green"
                  value = 1
                }
              ]
            }
          }
          overrides = []
        }
        gridPos = {
          h = 8
          w = 12
          x = 12
          y = 12
        }
        id = 6
        options = {
          legend = {
            calcs       = []
            displayMode = "list"
            placement   = "bottom"
            showLegend  = true
          }
          tooltip = {
            hideZeros = false
            mode      = "single"
            sort      = "none"
          }
        }
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid  = "Prometheus"
            }
            expr         = "up"
            legendFormat = "{{job}} {{instance}}"
            refId        = "A"
          }
        ]
        title = "Prometheus Targets"
        type  = "timeseries"
      }
    ]
    refresh       = "10s"
    schemaVersion = 42
    tags          = ["kubernetes", "portable-voting", "bachelor-thesis"]
    templating = {
      list = []
    }
    time = {
      from = "now-6h"
      to   = "now"
    }
    timepicker = {}
    timezone   = "browser"
    title      = "Portable Voting App / Kubernetes Overview"
    uid        = "portable-voting-overview"
    version    = 1
    weekStart  = ""
  }
}

resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_address" "ingress" {
  name   = "${var.cluster_name}-ingress"
  region = local.gke_region

  depends_on = [google_project_service.required]
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.location

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  # Dataplane V2 setzt NetworkPolicies ohne weiteres Add-on durch.
  datapath_provider = "ADVANCED_DATAPATH"

  release_channel {
    channel = "REGULAR"
  }

  depends_on = [google_project_service.required]
}

resource "google_container_node_pool" "default" {
  name       = "default-pool"
  cluster    = google_container_cluster.primary.name
  location   = var.location
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

data "kubernetes_config_map_v1" "gke_dataplane_v2" {
  metadata {
    name      = "cilium-config"
    namespace = "kube-system"
  }

  depends_on = [google_container_node_pool.default]
}

resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = var.ingress_namespace
  }

  depends_on = [google_container_node_pool.default]
}

resource "kubernetes_namespace_v1" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name = var.monitoring_namespace
  }

  depends_on = [google_container_node_pool.default]
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

  depends_on = [google_container_node_pool.default]
}

resource "terraform_data" "ghcr_pull_secret" {
  triggers_replace = [
    var.project_id,
    var.location,
    var.cluster_name,
    var.app_namespace,
    var.ghcr_username,
    var.image_pull_secret_name
  ]

  provisioner "local-exec" {
    command = "\"${path.module}/../../scripts/create-ghcr-pull-secret.sh\""

    environment = {
      PROJECT_ID    = var.project_id
      GKE_LOCATION  = var.location
      CLUSTER_NAME  = var.cluster_name
      NAMESPACE     = var.app_namespace
      GHCR_USERNAME = var.ghcr_username
      SECRET_NAME   = var.image_pull_secret_name
    }
  }

  depends_on = [kubernetes_namespace_v1.app]
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "41.0.2"
  namespace  = kubernetes_namespace_v1.traefik.metadata[0].name

  wait    = true
  timeout = 900

  values = [
    yamlencode({
      ingressClass = {
        enabled        = true
        isDefaultClass = true
        name           = "traefik"
      }
      providers = {
        kubernetesCRD = {
          enabled = false
        }
        kubernetesIngress = {
          enabled      = true
          ingressClass = "traefik"
          publishedService = {
            enabled = true
          }
        }
      }
      service = {
        spec = {
          type           = "LoadBalancer"
          loadBalancerIP = google_compute_address.ingress.address
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

  depends_on = [kubernetes_namespace_v1.traefik]
}

resource "helm_release" "voting_app" {
  name      = "voting"
  chart     = "${path.module}/../../charts/voting-app"
  namespace = kubernetes_namespace_v1.app.metadata[0].name

  wait    = true
  timeout = 900

  values = [
    file("${path.module}/../../charts/voting-app/values-gke.yaml"),
    yamlencode({
      imagePullSecrets = [
        {
          name = var.image_pull_secret_name
        }
      ]
      vote = {
        image = {
          repository = "${var.image_repository_base}/vote"
          tag        = var.image_tag
        }
        ingress = {
          className = "traefik"
          host      = local.vote_host
        }
      }
      result = {
        image = {
          repository = "${var.image_repository_base}/result"
          tag        = var.image_tag
        }
        ingress = {
          className = "traefik"
          host      = local.result_host
        }
      }
      worker = {
        image = {
          repository = "${var.image_repository_base}/worker"
          tag        = var.image_tag
        }
      }
      postgres = {
        password = var.postgres_password
      }
      networkPolicy = {
        allowNodeLocalDns = true
        healthProbeCidrs = [
          format("%s/32", data.kubernetes_config_map_v1.gke_dataplane_v2.data["local-router-ipv4"])
        ]
      }
      ingressController = {
        namespace = var.ingress_namespace
      }
    })
  ]

  depends_on = [
    helm_release.traefik,
    terraform_data.ghcr_pull_secret
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
        ingressClassName = "traefik"
        hosts            = [local.grafana_host]
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
              uid       = "Prometheus"
              url       = "http://prometheus-server.monitoring.svc.cluster.local"
              access    = "proxy"
              isDefault = true
            }
          ]
        }
      }
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "default"
              orgId           = 1
              folder          = "Kubernetes"
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }
          ]
        }
      }
      dashboards = {
        default = {
          "portable-voting-overview" = {
            json = jsonencode(local.grafana_portable_dashboard)
          }
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
    helm_release.traefik,
    helm_release.prometheus
  ]
}
