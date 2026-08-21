variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the target cluster. Supplied at apply time -- the Deployment Agent writes the user's uploaded kubeconfig to a temporary path and passes it here."
  type        = string
}

variable "kube_context" {
  description = "kubeconfig context to use. Leave null for single-context kubeconfigs."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
  default     = "bankai"
}

variable "environment" {
  description = "Deployment environment (used in names/labels)."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Identifier of the target Kubernetes cluster, for display/output purposes only (NOT used for provider connection)."
  type        = string
  default     = "devops-testing"
}

variable "namespace_name" {
  description = "Kubernetes namespace name to create for this deployment."
  type        = string
  default     = "bankai-dev-ns"
}

variable "image_backend" {
  description = "Container image URI for Backend"
  type        = string
  default     = "bankai-backend:v1"
}

variable "image_frontend" {
  description = "Container image URI for Frontend"
  type        = string
  default     = "bankai-frontend:v1"
}

variable "jwt_secret_key" {
  description = "Sensitive value for JWT_SECRET_KEY. Supplied at `terraform apply` time via -var or an untracked .tfvars file -- never given a default, never committed."
  type        = string
  sensitive   = true
}
