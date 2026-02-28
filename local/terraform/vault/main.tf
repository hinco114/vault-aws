# Helm Provider 를 설정합니다. (Docker Desktop k8s 클러스터에 접근하기 위한 설정)
provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

# Vault Helm Chart 를 사용하여 Vault 를 설치합니다.
resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault"
  create_namespace = true

  # Vault Helm Chart 값을 설정합니다. (HA 모드 및 Raft 스토리지 활성화)
  values = [
    <<-EOF
    server:
      affinity: ""
      persistentVolumeClaimRetentionPolicy:
        whenDeleted: Delete
        whenScaled: Retain
      ha:
        enabled: true
        replicas: 3
        raft:
          enabled: true
          setNodeId: true
          config: |
            ui = true
            listener "tcp" {
              tls_disable = 1
              address = "[::]:8200"
              cluster_address = "[::]:8201"
            }
            storage "raft" {
              path = "/vault/data"
              retry_join {
                leader_api_addr = "http://vault-0.vault-internal:8200"
              }
            }
    ui:
      enabled: true
      serviceType: LoadBalancer
    EOF
  ]
}

# Vault Service 정보를 가져옵니다.
data "kubernetes_service_v1" "vault_ui" {
  metadata {
    name      = "vault-ui"
    namespace = helm_release.vault.namespace
  }

  depends_on = [
    helm_release.vault
  ]
}
