locals {
  name                = "vault-local"
  aws_profile         = "default"
  aws_region          = "ap-northeast-2"
  kube_config_path    = "~/.kube/config" # 반드시 사전에 config 가 존재해야 함
  kube_config_context = "docker-desktop" # 반드시 사전에 context 가 존재해야 함
}

provider "helm" {
  kubernetes {
    config_path    = local.kube_config_path
    config_context = local.kube_config_context
  }
}

provider "kubernetes" {
  config_path    = local.kube_config_path
  config_context = local.kube_config_context
}

provider "aws" {
  profile = local.aws_profile
  region  = local.aws_region
}

module "iam" {
  source   = "../modules/aws-iam-auth"
  use_irsa = false
}

module "vault" {
  source = "../modules/vault-server"

  helm_values = [
    <<-EOF
    server:
      affinity: ""
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

output "iam_access_key_id" {
  value = module.iam.iam_access_key_id
}
output "iam_secret_access_key" {
  value     = module.iam.iam_secret_access_key
  sensitive = true
}
output "vault_sts_target_role_arn" {
  value = module.iam.sts_target_role_arn
}
output "vault_ui_url" {
  value = module.vault.vault_ui_url
}
