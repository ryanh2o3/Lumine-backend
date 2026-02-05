output "redis_host" {
  description = "Redis host address"
  value = var.use_managed_redis ? (
    length(scaleway_redis_cluster.main) > 0 ? scaleway_redis_cluster.main[0].private_network[0].endpoint_id : null
  ) : (
    length(scaleway_instance_server.redis) > 0 ? scaleway_instance_server.redis[0].private_ip : null
  )
}

output "redis_port" {
  description = "Redis port"
  value = var.use_managed_redis ? 6379 : 6379
}

output "redis_url" {
  description = "Full Redis connection URL"
  value = var.use_managed_redis ? (
    length(scaleway_redis_cluster.main) > 0 ? (
      var.managed_redis_tls_enabled ?
        "rediss://:${var.redis_password}@${scaleway_redis_cluster.main[0].private_network[0].endpoint_id}:6379" :
        "redis://:${var.redis_password}@${scaleway_redis_cluster.main[0].private_network[0].endpoint_id}:6379"
    ) : null
  ) : (
    length(scaleway_instance_server.redis) > 0 ?
      "redis://:${var.redis_password}@${scaleway_instance_server.redis[0].private_ip}:6379" : null
  )
  sensitive = true
}

output "self_managed_instance_id" {
  description = "Self-managed Redis instance ID"
  value       = var.use_managed_redis ? null : (length(scaleway_instance_server.redis) > 0 ? scaleway_instance_server.redis[0].id : null)
}

output "managed_cluster_id" {
  description = "Managed Redis cluster ID"
  value       = var.use_managed_redis ? (length(scaleway_redis_cluster.main) > 0 ? scaleway_redis_cluster.main[0].id : null) : null
}

output "is_managed" {
  description = "Whether using managed Redis"
  value       = var.use_managed_redis
}

output "redis_use_tls" {
  description = "Whether Redis connections should use TLS"
  value       = var.use_managed_redis ? var.managed_redis_tls_enabled : false
}
