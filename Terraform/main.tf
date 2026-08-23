data "kubernetes_nodes" "all" {}

locals {
  node_addresses = data.kubernetes_nodes.all.nodes[0].status[0].addresses
  node_ip = coalesce(
    try([for a in local.node_addresses : a.address if a.type == "ExternalIP"][0], null),
    try([for a in local.node_addresses : a.address if a.type == "InternalIP"][0], null),
  )
}

resource "kubernetes_namespace" "bankai_dev_ns" {
  metadata {
    name = "bankai-dev-ns"
    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }
  }
}

resource "kubernetes_secret" "bankai_dev_backend_secret" {
  metadata {
    name = "bankai-dev-backend-secret"
    namespace = kubernetes_namespace.bankai_dev_ns.metadata[0].name
    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }
  }

  data = {
    "JWT_SECRET_KEY" = var.jwt_secret_key
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.bankai_dev_ns]
}

resource "kubernetes_config_map" "backend_configmap" {
  metadata {
    name = "${var.project_name}-${var.environment}-backend-cm"
    namespace = kubernetes_namespace.bankai_dev_ns.metadata[0].name
    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }
  }

  data = {
    DATABASE_URL               = "sqlite:///./app.db"
    PORT                       = "8000"
    ACCESS_TOKEN_EXPIRE_MINUTES = "60"
    ENVIRONMENT                = "development"
    # CORS_ORIGINS is computed (reverse-cors-origin) and must be Frontend's public URL
    CORS_ORIGINS = "http://${local.node_ip}:${kubernetes_service.frontend_service.spec[0].port[0].node_port}"
  }

  depends_on = [kubernetes_namespace.bankai_dev_ns]
}

resource "kubernetes_service" "backend_service" {
  metadata {
    name = "${var.project_name}-${var.environment}-backend-svc"
    namespace = kubernetes_namespace.bankai_dev_ns.metadata[0].name
    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }
  }

  spec {
    selector = {
      app = "${var.project_name}-${var.environment}-backend"
    }
    type = "NodePort"

    port {
      port        = 8000
      target_port = 8000
      node_port   = 30080
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_namespace.bankai_dev_ns]
}

resource "kubernetes_deployment" "backend_deployment" {
  metadata {
    name = "${var.project_name}-${var.environment}-backend"
    namespace = kubernetes_namespace.bankai_dev_ns.metadata[0].name
    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
      app         = "${var.project_name}-${var.environment}-backend"
    }
  }

  spec {
    replicas = var.backend_replicas

    selector {
      match_labels = {
        app = "${var.project_name}-${var.environment}-backend"
      }
    }

    template {
      metadata {
        labels = {
          environment = var.environment
          project     = var.project_name
          managed_by  = "terraform"
          app         = "${var.project_name}-${var.environment}-backend"
        }
      }

      spec {
        container {
          name  = "backend"
          image = var.backend_image

          port {
            container_port = 8000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.backend_configmap.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.bankai_dev_backend_secret.metadata[0].name
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "8000"
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "8000"
              scheme = "HTTP"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.bankai_dev_ns,
    kubernetes_config_map.backend_configmap,
    kubernetes_secret.bankai_dev_backend_secret
  ]
}

resource "kubernetes_config_map" "frontend_configmap" {
  metadata {
    name = "${var.project_name}-${var.environment}-frontend-cm"
    namespace = kubernetes_namespace.bankai_dev_ns.metadata[0].name
    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }
  }

  data = {
    # VITE_API_URL is computed at apply time as the cluster node IP plus Backend's pinned NodePort
    VITE_API_URL = "http://${local.node_ip}:${kubernetes_service.backend_service.spec[0].port[0].node_port}"
  }

  depends_on = [
    kubernetes_namespace.bankai_dev_ns,
    kubernetes_service.backend_service
  ]
}

resource "kubernetes_deployment" "frontend_deployment" {
  metadata {
    name = "${var.project_name}-${var.environment}-frontend"
    namespace = kubernetes_namespace.bankai_dev_ns.metadata[0].name
    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
      app         = "${var.project_name}-${var.environment}-frontend"
    }
  }

  spec {
    replicas = var.frontend_replicas

    selector {
      match_labels = {
        app = "${var.project_name}-${var.environment}-frontend"
      }
    }

    template {
      metadata {
        labels = {
          environment = var.environment
          project     = var.project_name
          managed_by  = "terraform"
          app         = "${var.project_name}-${var.environment}-frontend"
        }
      }

      spec {
        container {
          name  = "frontend"
          image = var.frontend_image

          port {
            container_port = 80
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.frontend_configmap.metadata[0].name
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "80"
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "80"
              scheme = "HTTP"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.bankai_dev_ns,
    kubernetes_config_map.frontend_configmap
  ]
}

resource "kubernetes_service" "frontend_service" {
  metadata {
    name = "${var.project_name}-${var.environment}-frontend-svc"
    namespace = kubernetes_namespace.bankai_dev_ns.metadata[0].name
    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }
  }

  spec {
    selector = {
      app = "${var.project_name}-${var.environment}-frontend"
    }
    type = "NodePort"

    port {
      port        = 80
      target_port = 80
      node_port   = 30081
      protocol    = "TCP"
    }
  }

  depends_on = [
    kubernetes_namespace.bankai_dev_ns,
    kubernetes_deployment.frontend_deployment
  ]
}
