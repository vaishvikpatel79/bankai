terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
  }
}
# backend {}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}
