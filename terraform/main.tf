locals {
  name   = "vault-aws"
  region = "ap-northeast-2"
}

provider "aws" {
  region = local.region
  default_tags {
    tags = {
      Project     = local.name
      Environment = "dev"
      Terraform   = "true"
    }
  }
}

# 현재 접속한 IP 정보를 가져옵니다.
data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}

# 현재 접속한 IP를 CIDR 형식으로 변환합니다.
locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

module "eks" {
  source = "./modules/eks"

  name       = local.name
  region     = local.region
  my_ip_cidr = local.my_ip_cidr
}

module "vault" {
  source = "./modules/vault"

  region                  = local.region
  my_ip_cidr             = local.my_ip_cidr
  cluster_name            = module.eks.cluster_name
  cluster_endpoint        = module.eks.cluster_endpoint
  cluster_ca_certificate  = module.eks.cluster_certificate_authority_data
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn       = module.eks.oidc_provider_arn

}

output "vault_ui_lb_hostname" {
  description = "External Vault URL for UI/API service."
  value       = module.vault.vault_ui_lb_hostname
}
