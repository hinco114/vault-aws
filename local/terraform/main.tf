locals {
  name         = "vault-local"
  kube_context = "docker-desktop"
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

module "vault" {
  source = "./modules/vault"

  kubeconfig_path    = "~/.kube/config"
  kube_context       = local.kube_context
  vault_ui_node_port = 30200
}

output "vault_ui_url" {
  description = "로컬 Vault UI URL."
  value       = module.vault.vault_ui_url
}
