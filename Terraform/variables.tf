variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the target cluster. Supplied at apply time -- the Deployment Agent writes the user's uploaded kubeconfig to a temporary path and passes it here."
  type        = string
}

variable "kube_context" {
  description = "kubeconfig context to use. Leave null for single-context kubeconfigs."
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "Identifier of the target Kubernetes cluster, for display/output purposes only (NOT used for provider connection -- see kube_context)."
  type        = string
  default     = "devops-testing"
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
  default     = "bankai"
}

variable "environment" {
  description = "Deployment environment used for resource naming."
  type        = string
  default     = "dev"
}

variable "backend_image" {
  description = "Container image URI for Backend"
  type        = string
}

variable "frontend_image" {
  description = "Container image URI for Frontend"
  type        = string
}

variable "backend_replicas" {
  description = "Replica count for Backend"
  type        = number
  default     = 1
}

variable "frontend_replicas" {
  description = "Replica count for Frontend"
  type        = number
  default     = 1
}

variable "jwt_secret_key" {
  description = "Sensitive value for JWT_SECRET_KEY. Supplied at `terraform apply` time via -var or an untracked .tfvars file -- never given a default."
  type        = string
  sensitive   = true
}
