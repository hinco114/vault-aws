terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# 이름 충돌을 피하기 위해 랜덤 접미사 생성
resource "random_id" "suffix" {
  byte_length = 3
}

# 테스트용 IAM 사용자 생성
resource "aws_iam_user" "demo_user" {
  name = "vault-local-credential-${random_id.suffix.hex}"
}

# 위 IAM 사용자에 대한 Access Key 를 발급
resource "aws_iam_access_key" "demo_user" {
  user = aws_iam_user.demo_user.name
}

# Vault AWS Secrets Engine 사용 권한 정책 문서 생성
data "aws_iam_policy_document" "vault_aws_secrets_engine" {
  statement {
    effect = "Allow"

    actions = [
      "iam:*"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    resources = [
      aws_iam_role.vault_sts_target.arn
    ]
  }
}

# 생성한 정책을 IAM 사용자에 인라인 정책으로 연결
resource "aws_iam_user_policy" "vault_aws_secrets_engine" {
  name   = "vault-local-credential-vault-aws-${random_id.suffix.hex}"
  user   = aws_iam_user.demo_user.name
  policy = data.aws_iam_policy_document.vault_aws_secrets_engine.json
}

# Vault 가 STS AssumeRole 대상으로 사용할 IAM Role 신뢰 정책 생성
data "aws_iam_policy_document" "vault_sts_target_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "AWS"
      identifiers = [
        aws_iam_user.demo_user.arn
      ]
    }
  }
}

# Vault STS AssumeRole 대상 IAM Role 생성
resource "aws_iam_role" "vault_sts_target" {
  name               = "vault-local-sts-target-${random_id.suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.vault_sts_target_assume_role.json
}

# 위 Role 에 SecretsManagerReadWrite 관리형 정책 연결
resource "aws_iam_role_policy_attachment" "vault_sts_target_secrets_rw" {
  role       = aws_iam_role.vault_sts_target.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}
