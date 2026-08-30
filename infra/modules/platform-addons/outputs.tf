output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = random_password.grafana.result
  sensitive   = true
}

output "gateway_namespace" {
  description = "Namespace of the shared Gateway"
  value       = kubernetes_namespace.gateway.metadata[0].name
}
