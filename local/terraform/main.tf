locals {
  name         = "vault-local"
  kube_context = "docker-desktop"
}

# Vault Module
module "vault" {
  source = "./modules/vault"

  kubeconfig_path    = "~/.kube/config"
  kube_context       = local.kube_context
}

# AWS Credential Module
module "aws_credential" {
  source = "./modules/aws_credential"
}

output "demo_access_key_id" {
  description = "예제용 Access Key ID."
  value       = module.aws_credential.access_key_id
}

output "demo_secret_access_key" {
  description = "예제용 Secret Access Key."
  value       = module.aws_credential.secret_access_key
  sensitive   = true
}

output "demo_assume_role_arn" {
  description = "Vault STS AssumeRole 대상 IAM Role ARN."
  value       = module.aws_credential.assume_role_arn
}
