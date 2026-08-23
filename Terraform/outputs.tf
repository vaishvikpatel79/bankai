output "node_ip" {
  description = "Cluster node IP used for NodePort service access"
  value       = local.node_ip
}

output "kubernetes_namespace" {
  description = "Kubernetes Namespace created for the application"
  value       = kubernetes_namespace.bankai_dev_ns.metadata[0].name
}

output "frontend_deployment_name" {
  description = "Frontend Deployment Name"
  value       = kubernetes_deployment.frontend_deployment.metadata[0].name
}

output "backend_deployment_name" {
  description = "Backend Deployment Name"
  value       = kubernetes_deployment.backend_deployment.metadata[0].name
}

output "frontend_service_name" {
  description = "Frontend Service Name"
  value       = kubernetes_service.frontend_service.metadata[0].name
}

output "backend_service_name" {
  description = "Backend Service Name"
  value       = kubernetes_service.backend_service.metadata[0].name
}

output "frontend_endpoint_nodeport" {
  description = "Frontend public endpoint (NodePort)"
  value       = "http://${local.node_ip}:${kubernetes_service.frontend_service.spec[0].port[0].node_port}"
}

output "backend_endpoint_nodeport" {
  description = "Backend public endpoint (NodePort)"
  value       = "http://${local.node_ip}:${kubernetes_service.backend_service.spec[0].port[0].node_port}"
}

output "deployment_contract" {
  description = "Canonical deployment contract for the Deployment Agent"
  value = {
    meta = {
      contract_version = "1.0"
      cloud            = "kubernetes"
      runtime          = "kubernetes"
      application_type = "fullstack"
      environment      = var.environment
      region           = null
      deployment_type  = "k8s"
    }

    compute = {
      cluster_name = var.cluster_name
      service_name = null
      service_names = {
        Backend  = kubernetes_deployment.backend_deployment.metadata[0].name
        Frontend = kubernetes_deployment.frontend_deployment.metadata[0].name
      }
      task_family   = null
      workload_name = null
    }

    network = {
      vpc_id = null
      subnet_ids = null
      security_group_ids = null
      ingress_id = null
    }

    routing = {
      public_endpoint = jsonencode({
        Frontend = "http://${local.node_ip}:${kubernetes_service.frontend_service.spec[0].port[0].node_port}",
        Backend  = "http://${local.node_ip}:${kubernetes_service.backend_service.spec[0].port[0].node_port}"
      })
      internal_endpoint = null
      custom_domain = null
      certificate_required = false
      certificate_mode = null
    }

    data = {
      database_endpoint = null
      cache_endpoint = null
      object_store_name = null
    }

    security = {
      certificate_ref = null
      secret_refs = {
        JWT_SECRET = kubernetes_secret.bankai_dev_backend_secret.metadata[0].name
      }
      role_arns = null
    }

    health = {
      frontend_path = "/"
      backend_path = "/health"
      readiness_path = "/health"
      liveness_path = "/health"
    }
  }
}
