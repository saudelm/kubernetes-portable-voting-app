locals {
  vote_url    = "http://vote.${var.host_suffix}:${var.http_port}"
  result_url  = "http://result.${var.host_suffix}:${var.http_port}"
  grafana_url = "http://grafana.${var.host_suffix}:${var.http_port}"
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
            expr         = "sum(kube_pod_status_phase{namespace=\"${var.app_namespace}\",phase=\"Running\"})"
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
            expr         = "sum(kube_pod_container_status_restarts_total{namespace=\"${var.app_namespace}\"})"
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
            expr         = "sum by (pod) (rate(container_cpu_usage_seconds_total{namespace=\"${var.app_namespace}\",pod!=\"\",container!=\"POD\",image!=\"\"}[5m]))"
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
            expr         = "sum by (pod) (container_memory_working_set_bytes{namespace=\"${var.app_namespace}\",pod!=\"\",container!=\"POD\",image!=\"\"})"
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
            expr         = "sum by (deployment) (kube_deployment_status_replicas_available{namespace=\"${var.app_namespace}\"})"
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

resource "kubernetes_namespace_v1" "traefik" {
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
    name        = var.app_namespace
    annotations = var.isolated_test ? { "testing.portable-voting/release" = var.app_release } : {}
    labels = merge({
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }, var.isolated_test ? { "testing.portable-voting/isolated" = "true" } : {})
  }
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
          type = "LoadBalancer"
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
  name      = var.app_release
  chart     = "${path.module}/../../charts/voting-app"
  namespace = kubernetes_namespace_v1.app.metadata[0].name

  wait    = true
  timeout = 900

  values = [
    yamlencode({
      vote = {
        image = {
          repository = var.image_repositories["vote"]
          tag        = var.image_tag
        }
        ingress = { host = "vote.${var.host_suffix}" }
      }
      result = {
        image = {
          repository = var.image_repositories["result"]
          tag        = var.image_tag
        }
        ingress = { host = "result.${var.host_suffix}" }
      }
      worker = {
        image = {
          repository = var.image_repositories["worker"]
          tag        = var.image_tag
        }
      }
      postgres = {
        password = var.postgres_password
      }
      ingressController = {
        namespace = var.ingress_namespace
      }
    })
  ]

  depends_on = [
    helm_release.traefik,
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
        resources = {
          requests = { cpu = "30m", memory = "64Mi" }
          limits   = { cpu = "200m", memory = "192Mi" }
        }
      }
      "prometheus-node-exporter" = {
        enabled = true
        resources = {
          requests = { cpu = "20m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }
      }
      configmapReload = {
        prometheus = {
          resources = {
            requests = { cpu = "10m", memory = "32Mi" }
            limits   = { cpu = "100m", memory = "128Mi" }
          }
        }
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
      testFramework = { enabled = false }
      downloadDashboards = {
        resources = {
          requests = { cpu = "10m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }
      }
      initChownData = {
        resources = {
          requests = { cpu = "10m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "128Mi" }
        }
      }
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled          = true
        ingressClassName = "traefik"
        hosts            = ["grafana.${var.host_suffix}"]
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
              url       = "http://prometheus-server.${var.monitoring_namespace}.svc.cluster.local"
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
