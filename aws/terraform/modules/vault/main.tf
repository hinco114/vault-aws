# Helm Provider 를 설정합니다. (EKS 클러스터에 접근하기 위한 설정)
provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}

# Helm Destroy 시 EKS 리소스가 삭제된 후 120초 동안 대기합니다. (연관 리소스가 잘 삭제되도록 하기 위함)
resource "terraform_data" "wait_after_helm_destroy" {
  provisioner "local-exec" {
    when    = destroy
    command = "sleep 120"
  }
}

locals {
  vault_role_name     = "vault-role"
  vault_oidc_provider = replace(var.cluster_oidc_issuer_url, "https://", "")
  vault_sa_subject    = "system:serviceaccount:vault:vault"
}

# IRSA 로 사용하기 위한 IAM Policy 를 생성합니다. (KMS 접근 권한)
resource "aws_iam_policy" "vault_policy" {
  name = "vault-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# IRSA 로 사용하기 위한 IAM Role 을 생성합니다.
resource "aws_iam_role" "vault_role" {
  name = local.vault_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${local.vault_oidc_provider}:sub" = local.vault_sa_subject
            "${local.vault_oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# IAM Role 과 IAM Policy 를 연결합니다.
resource "aws_iam_role_policy_attachment" "vault_policy_attachment" {
  role       = aws_iam_role.vault_role.name
  policy_arn = aws_iam_policy.vault_policy.arn
}

# KMS Key 를 생성합니다.
resource "aws_kms_key" "vault" {
  description             = "Vault KMS Key"
  deletion_window_in_days = 7
}

# KMS Key 를 위한 Alias 를 생성합니다.
resource "aws_kms_alias" "vault" {
  name          = "alias/vault"
  target_key_id = aws_kms_key.vault.key_id
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
            seal "awskms" {
              kms_key_id = "${aws_kms_key.vault.key_id}"
              region = "${var.region}"
            }
      serviceAccount:
        annotations:
          eks.amazonaws.com/role-arn: ${aws_iam_role.vault_role.arn}
    ui:
      enabled: true
      serviceType: LoadBalancer
      loadBalancerSourceRanges: ["${var.my_ip_cidr}"]
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
        service.beta.kubernetes.io/aws-load-balancer-type: external
    EOF
  ]

  depends_on = [
    terraform_data.wait_after_helm_destroy
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
