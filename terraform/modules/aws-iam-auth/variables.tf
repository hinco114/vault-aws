variable "use_irsa" {
  type    = bool
  default = false
}
variable "oidc_provider_arn" {
  type    = string
  default = ""
}
variable "oidc_issuer_url" {
  type    = string
  default = ""
}
variable "kms_key_arn" {
  description = "KMS Key ARN for Vault auto-unseal"
  type        = string
  default     = ""
}
