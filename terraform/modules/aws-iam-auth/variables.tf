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

variable "use_kms" {
  description = "KMS Policy 및 Role Attachment 생성 여부 (kms_key_arn 이 apply 전 미정이므로 별도 bool 로 제어)"
  type        = bool
  default     = false
}
