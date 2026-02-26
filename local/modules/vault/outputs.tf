output "vault_ui_url" {
  description = "로컬 Vault UI URL."
  value = try(
    format("http://localhost:%d", data.kubernetes_service_v1.vault_ui.spec[0].port[0].node_port),
    format("http://localhost:%d", var.vault_ui_node_port),
  )
}
