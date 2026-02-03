output "registry_namespace_id" {
  description = "Container registry namespace ID"
  value       = scaleway_registry_namespace.main.id
}

output "registry_endpoint" {
  description = "Container registry endpoint"
  value       = scaleway_registry_namespace.main.endpoint
}

output "api_instance_ids" {
  description = "API instance IDs"
  value       = scaleway_instance_server.api[*].id
}

output "api_instance_private_ips" {
  description = "API instance private IPs"
  value       = scaleway_instance_server.api[*].private_ip
}

output "api_instance_public_ips" {
  description = "API instance public IPs (if assigned)"
  value       = scaleway_instance_server.api[*].public_ip
}

output "worker_instance_ids" {
  description = "Worker instance IDs"
  value       = scaleway_instance_server.worker[*].id
}

output "worker_instance_private_ips" {
  description = "Worker instance private IPs"
  value       = scaleway_instance_server.worker[*].private_ip
}
