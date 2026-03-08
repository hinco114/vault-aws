terraform {
  required_providers {
    helm       = { source = "hashicorp/helm", version = "~> 2.17" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.35" }
  }
}

# Helm Destroy 시 리소스가 완전히 삭제될 수 있도록 대기
resource "terraform_data" "wait_after_helm_destroy" {
  provisioner "local-exec" {
    when    = destroy
    command = "sleep 120"
  }
}

# Vault Chart 설치
# Chart URL : https://artifacthub.io/packages/helm/hashicorp/vault
resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault"
  create_namespace = true

  values = var.helm_values

  depends_on = [
    terraform_data.wait_after_helm_destroy
  ]
}

# Vault UI Service 조회
data "kubernetes_service_v1" "vault_ui" {
  metadata {
    name      = "vault-ui"
    namespace = helm_release.vault.namespace
  }
  depends_on = [helm_release.vault]
}

# Vault UI URL
output "vault_ui_hostname" {
  value = length(data.kubernetes_service_v1.vault_ui.status[0].load_balancer[0].ingress) > 0 ? data.kubernetes_service_v1.vault_ui.status[0].load_balancer[0].ingress[0].hostname : "localhost"
}
