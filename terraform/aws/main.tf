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
      loadBalancerSourceRanges: ["${local.my_ip_cidr}", "${module.eks.nat_public_ips[0]}/32"]
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
        service.beta.kubernetes.io/aws-load-balancer-type: external
    EOF
  ]
}

output "vault_ui_url" {
  value = module.vault.vault_ui_url
}
output "vault_role_arn" {
  value = module.iam.vault_role_arn
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

# Application IRSA Role (Vault 인증 전용)
# - Vault Auth Method: Kubernetes
# - 이 Role 을 ServiceAccount 에 어노테이션으로 지정하면 Vault 가 해당 Pod 의 identity 를 검증할 수 있음
resource "aws_iam_role" "app_irsa" {
  name = "sample-app2-vault-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:sample-app2-ns:sample-app2-sa"
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

output "app_irsa_role_arn" {
  description = "Application Vault IRSA Role ARN."
  value       = aws_iam_role.app_irsa.arn
}


# VSO (Vault Secrets Operator) 설치
# https://github.com/hashicorp/vault-secrets-operator
resource "helm_release" "vso" {
  name             = "vault-secrets-operator"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault-secrets-operator"
  namespace        = "vault-secrets-operator"
  create_namespace = true

  depends_on = [module.vault]
}
