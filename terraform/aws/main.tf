locals {
  name                = "vault-aws"
  region              = "ap-northeast-2"
  kube_config_path    = "~/.kube/config"
  kube_config_context = "arn:aws:eks:ap-northeast-2:341689148868:cluster/vault-aws"
}

provider "aws" {
  region = local.region
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

# 내 IP를 CIDR로 변환
data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}
locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

module "eks" {
  source     = "../modules/eks"
  name       = local.name
  region     = local.region
  my_ip_cidr = local.my_ip_cidr
}

module "iam" {
  source            = "../modules/aws-iam-auth"
  use_irsa          = true
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  kms_key_arn       = aws_kms_key.vault.arn
}

# Auto unseal을 위한 KMS Key 생성
resource "aws_kms_key" "vault" {
  description             = "Vault Auto-unseal Key"
  deletion_window_in_days = 7
}

# KMS Alias 생성
resource "aws_kms_alias" "vault" {
  name          = "alias/vault"
  target_key_id = aws_kms_key.vault.key_id
}

module "vault" {
  source = "../modules/vault-server"

  helm_values = [
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
            seal "awskms" {
              kms_key_id = "${aws_kms_key.vault.key_id}"
              region = "${local.region}"
            }
      serviceAccount:
        annotations:
          eks.amazonaws.com/role-arn: ${module.iam.vault_role_arn}
    ui:
      enabled: true
      serviceType: LoadBalancer
      loadBalancerSourceRanges: ["${local.my_ip_cidr}"]
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
        service.beta.kubernetes.io/aws-load-balancer-type: external
    EOF
  ]
}

output "vault_ui_url" {
  value = module.vault.vault_ui_url
}
output "vault_sts_target_role_arn" {
  value = module.iam.sts_target_role_arn
}
