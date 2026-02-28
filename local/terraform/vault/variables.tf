variable "kubeconfig_path" {
  type        = string
  description = "kubeconfig 파일 경로."
  default     = "~/.kube/config"
}

variable "kube_context" {
  type        = string
  description = "사용할 kubernetes context 이름."
  default     = "docker-desktop"
}

variable "vault_ui_node_port" {
  type        = number
  description = "Vault UI 에 접근할 NodePort 번호. (30000~32767)"
  default     = 30200
}
