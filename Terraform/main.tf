resource "kubernetes_namespace" "bankai_dev_ns" {
  metadata {
    name = var.namespace_name

    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }
  }
}

resource "kubernetes_secret" "bankai_dev_backend_secret" {
  metadata {
    name      = "${var.project_name}-${var.environment}-backend-secret"
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

resource "kubernetes_config_map" "cm_backend" {
  metadata {
    name      = "${var.project_name}-${var.environment}-backend-cm"
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
    # Computed reverse-CORS origin: use Frontend's public URL (node IP + pinned nodePort)
    CORS_ORIGINS               = "http://${local.node_ip}:${kubernetes_service.svc_frontend.spec[0].port[0].node_port}"
  }

  depends_on = [kubernetes_namespace.bankai_dev_ns]
}

resource "kubernetes_service" "svc_backend" {
  metadata {
    name      = "${var.project_name}-${var.environment}-backend-svc"
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

resource "kubernetes_deployment" "dep_backend" {
  metadata {
    name = "${var.project_name}-${var.environment}-backend-dep"

    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }

    namespace = kubernetes_namespace.bankai_dev_ns.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "${var.project_name}-${var.environment}-backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "${var.project_name}-${var.environment}-backend"
        }
      }

      spec {
        container {
          name  = "backend"
          image = var.image_backend

          port {
            container_port = 8000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.cm_backend.metadata[0].name
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
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [kubernetes_config_map.cm_backend, kubernetes_secret.bankai_dev_backend_secret, kubernetes_service.svc_backend, kubernetes_namespace.bankai_dev_ns]
}

data "kubernetes_nodes" "cluster_nodes" {}

locals {
  node_addresses = data.kubernetes_nodes.cluster_nodes.nodes[0].status[0].addresses
  node_ip = coalesce(
    try([for a in local.node_addresses : a.address if a.type == "ExternalIP"][0], null),
    try([for a in local.node_addresses : a.address if a.type == "InternalIP"][0], null),
  )
}

resource "kubernetes_config_map" "cm_frontend" {
  metadata {
    name      = "${var.project_name}-${var.environment}-frontend-cm"
    namespace = kubernetes_namespace.bankai_dev_ns.metadata[0].name

    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }
  }

  data = {
    # VITE_API_URL computed from cluster node IP and backend pinned NodePort
    VITE_API_URL = "http://${local.node_ip}:${kubernetes_service.svc_backend.spec[0].port[0].node_port}"
  }

  depends_on = [kubernetes_service.svc_backend, data.kubernetes_nodes.cluster_nodes, kubernetes_namespace.bankai_dev_ns]
}

resource "kubernetes_service" "svc_frontend" {
  metadata {
    name      = "${var.project_name}-${var.environment}-frontend-svc"
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

  depends_on = [kubernetes_namespace.bankai_dev_ns]
}

resource "kubernetes_deployment" "dep_frontend" {
  metadata {
    name = "${var.project_name}-${var.environment}-frontend-dep"

    labels = {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }

    namespace = kubernetes_namespace.bankai_dev_ns.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "${var.project_name}-${var.environment}-frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "${var.project_name}-${var.environment}-frontend"
        }
      }

      spec {
        container {
          name  = "frontend"
          image = var.image_frontend

          port {
            container_port = 80
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.cm_frontend.metadata[0].name
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [kubernetes_config_map.cm_frontend, kubernetes_service.svc_frontend, kubernetes_namespace.bankai_dev_ns]
}
