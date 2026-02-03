output "cockpit_enabled" {
  description = "Whether Cockpit is enabled"
  value       = var.enable_cockpit
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = var.enable_cockpit ? data.scaleway_cockpit.main[0].endpoints[0].grafana_url : null
}

output "metrics_url" {
  description = "Metrics push endpoint"
  value       = var.enable_cockpit ? data.scaleway_cockpit.main[0].endpoints[0].metrics_url : null
}

output "logs_url" {
  description = "Logs push endpoint"
  value       = var.enable_cockpit ? data.scaleway_cockpit.main[0].endpoints[0].logs_url : null
}

output "traces_url" {
  description = "Traces push endpoint"
  value       = var.enable_cockpit ? data.scaleway_cockpit.main[0].endpoints[0].traces_url : null
}

output "alertmanager_url" {
  description = "Alert manager URL"
  value       = var.enable_cockpit ? data.scaleway_cockpit.main[0].endpoints[0].alertmanager_url : null
}

output "cockpit_token" {
  description = "Cockpit token for pushing metrics/logs"
  value       = var.enable_cockpit ? scaleway_cockpit_token.main[0].secret_key : null
  sensitive   = true
}

output "grafana_user" {
  description = "Grafana username"
  value       = var.enable_cockpit ? scaleway_cockpit_grafana_user.main[0].login : null
}

output "grafana_password" {
  description = "Grafana user password"
  value       = var.enable_cockpit ? scaleway_cockpit_grafana_user.main[0].password : null
  sensitive   = true
}
