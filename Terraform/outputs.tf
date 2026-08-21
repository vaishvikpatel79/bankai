output "namespace" {
  description = "Kubernetes namespace created for the deployment"
  value       = kubernetes_namespace.bankai_dev_ns.metadata[0].name
}

output "frontend_deployment_name" {
  description = "Frontend Deployment name"
  value       = kubernetes_deployment.dep_frontend.metadata[0].name
}

output "backend_deployment_name" {
  description = "Backend Deployment name"
  value       = kubernetes_deployment.dep_backend.metadata[0].name
}

output "frontend_service_name" {
  description = "Frontend Service name"
  value       = kubernetes_service.svc_frontend.metadata[0].name
}

output "backend_service_name" {
  description = "Backend Service name"
  value       = kubernetes_service.svc_backend.metadata[0].name
}

output "node_ip" {
  description = "Cluster node IP used to reach NodePort services"
  value       = local.node_ip
}

output "frontend_endpoint" {
  description = "Frontend Endpoint (NodePort)"
  value       = "http://${local.node_ip}:${kubernetes_service.svc_frontend.spec[0].port[0].node_port}"
}

output "backend_endpoint" {
  description = "Backend Endpoint (NodePort)"
  value       = "http://${local.node_ip}:${kubernetes_service.svc_backend.spec[0].port[0].node_port}"
}

output "deployment_contract" {
  description = "Machine-readable deployment contract for the Deployment Agent"
  value = {
    meta = {
      contract_version = "1.0"
      cloud            = "kubernetes"
      runtime          = "kubernetes"
      application_type = "Fullstack app"
      environment      = var.environment
      region           = null
      deployment_type  = "nodeport"
    }

    compute = {
      cluster_name   = var.cluster_name
      service_name   = null
      service_names  = {
        "Frontend" = kubernetes_deployment.dep_frontend.metadata[0].name
        "Backend"  = kubernetes_deployment.dep_backend.metadata[0].name
      }
      task_family    = null
      workload_name  = null
    }

    network = {
      vpc_id             = null
      subnet_ids         = null
      security_group_ids = null
      ingress_id         = null
    }

    routing = {
      public_endpoint      = jsonencode({
        Frontend = "http://${local.node_ip}:${kubernetes_service.svc_frontend.spec[0].port[0].node_port}",
        Backend  = "http://${local.node_ip}:${kubernetes_service.svc_backend.spec[0].port[0].node_port}"
      })
      internal_endpoint    = null
      custom_domain        = null
      certificate_required = false
      certificate_mode     = null
    }

    data = {
      database_endpoint   = null
      cache_endpoint      = null
      object_store_name   = null
    }

    security = {
      certificate_ref = null
      secret_refs = {
        "bankai-dev-backend-secret" = kubernetes_secret.bankai_dev_backend_secret.metadata[0].name
      }
      role_arns = null
    }

    health = {
      frontend_path  = "/"
      backend_path   = "/health"
      readiness_path = "/health"
      liveness_path  = "/health"
    }
  }
}
