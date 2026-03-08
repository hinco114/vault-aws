resource "random_id" "suffix" {
  byte_length = 3
}

# 생성될 AccessKey 의 Policy
# - iam:* : Dynamic Secret 으로 IAM User 생성/관리
# - sts:AssumeRole : Dynamic Secret 으로 IAM Role Assume
resource "aws_iam_policy" "vault_aws_access" {
  name = "vault-aws-access-${random_id.suffix.hex}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["iam:*", "sts:GetCallerIdentity", "sts:AssumeRole"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# AccessKey 기반으로 사용할 IAM User
resource "aws_iam_user" "vault_user" {
  name = "vault-user-${random_id.suffix.hex}"
}

# AccessKey 생성
resource "aws_iam_access_key" "vault_user_key" {
  user = aws_iam_user.vault_user.name
}

# AccessKey에 Policy Attach
resource "aws_iam_user_policy_attachment" "vault_user_attach" {
  user       = aws_iam_user.vault_user.name
  policy_arn = aws_iam_policy.vault_aws_access.arn
}

# Dynamic Secret 으로 IAM Role Assume 테스트를 위한 STS Target Role
resource "aws_iam_role" "sts_target" {
  name = "vault-sts-target-role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = compact([
          var.use_irsa ? aws_iam_role.vault_irsa[0].arn : "",
          aws_iam_user.vault_user.arn
        ])
      }
    }]
  })
}

# STS Target Role에 Policy Attach
resource "aws_iam_role_policy_attachment" "sts_target_sm" {
  role       = aws_iam_role.sts_target.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# (EKS) Vault Pod 에 할당하게 될 IAM Role
resource "aws_iam_role" "vault_irsa" {
  count = var.use_irsa ? 1 : 0
  name  = "vault-irsa-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${var.oidc_issuer_url}:sub" = "system:serviceaccount:vault:vault"
          "${var.oidc_issuer_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# (EKS) Vault Pod 에 할당하게 될 IAM Role에 Policy Attach
resource "aws_iam_role_policy_attachment" "vault_irsa_attach" {
  count      = var.use_irsa ? 1 : 0
  role       = aws_iam_role.vault_irsa[0].name
  policy_arn = aws_iam_policy.vault_aws_access.arn
}

# (EKS) Vault Auto-unseal 을 위한 KMS Policy
resource "aws_iam_policy" "vault_kms" {
  count = var.kms_key_arn != "" ? 1 : 0
  name  = "vault-kms-unseal-${random_id.suffix.hex}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      Effect   = "Allow"
      Resource = var.kms_key_arn
    }]
  })
}

# (EKS) Vault IRSA Role 에 KMS Policy Attach
resource "aws_iam_role_policy_attachment" "vault_irsa_kms" {
  count      = var.use_irsa && var.kms_key_arn != "" ? 1 : 0
  role       = aws_iam_role.vault_irsa[0].name
  policy_arn = aws_iam_policy.vault_kms[0].arn
}

# --- Outputs ---
output "vault_role_arn" {
  value = var.use_irsa ? aws_iam_role.vault_irsa[0].arn : ""
}

output "iam_access_key_id" {
  value = var.use_irsa ? "" : aws_iam_access_key.vault_user_key.id
}

output "iam_secret_access_key" {
  value     = var.use_irsa ? "" : aws_iam_access_key.vault_user_key.secret
  sensitive = true
}

output "sts_target_role_arn" {
  value = aws_iam_role.sts_target.arn
}
