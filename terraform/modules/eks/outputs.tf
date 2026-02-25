output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded EKS cluster CA bundle."
  value       = module.eks_cluster.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster."
  value       = module.eks_cluster.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN attached to the EKS cluster."
  value       = module.eks_cluster.oidc_provider_arn
}
