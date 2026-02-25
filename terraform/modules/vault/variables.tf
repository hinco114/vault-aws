variable "region" {
  type        = string
  description = "AWS region for Vault resources."
}

variable "my_ip_cidr" {
  type        = string
  description = "CIDR allowed for Vault UI/LoadBalancer."
}

variable "cluster_name" {
  type        = string
  description = "Target EKS cluster name."
}

variable "cluster_endpoint" {
  type        = string
  description = "EKS cluster endpoint."
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Base64 encoded EKS cluster CA certificate."
}

variable "cluster_oidc_issuer_url" {
  type        = string
  description = "EKS OIDC issuer URL."
}

variable "oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN for the EKS cluster."
}
