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

# Secrets Manager 사용 권한 정책 문서 생성
data "aws_iam_policy_document" "secrets_manager_demo" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:*"
    ]

    resources = [
      "*"
    ]
  }
}

# 생성한 정책을 IAM 사용자에 인라인 정책으로 연결
resource "aws_iam_user_policy" "secrets_manager_demo" {
  name   = "vault-local-credential-sm-${random_id.suffix.hex}"
  user   = aws_iam_user.demo_user.name
  policy = data.aws_iam_policy_document.secrets_manager_demo.json
}
