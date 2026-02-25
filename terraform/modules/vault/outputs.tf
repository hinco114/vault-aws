output "vault_ui_lb_hostname" {
  description = "External Vault URL for UI/API service."
  value = try(
    format("http://%s:8200", data.kubernetes_service_v1.vault_ui.status[0].load_balancer[0].ingress[0].hostname),
    null,
  )
}
