variable "helm_values" {
  description = "Additional YAML values for the Helm release"
  type        = list(string)
  default     = []
}
