# Outputs for staging environment

output "load_balancer_ip" {
  description = "Load balancer public IP"
  value       = module.networking.load_balancer_ip
}

output "api_instance_ips" {
  description = "Private IPs of API instances"
  value       = module.compute.api_instance_ips
}

output "worker_instance_ips" {
  description = "Private IPs of worker instances"
  value       = module.compute.worker_instance_ips
}

output "database_url" {
  description = "Database connection URL"
  value       = module.database.database_url
  sensitive   = true
}

output "redis_url" {
  description = "Redis connection URL"
  value       = module.cache.redis_url
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 bucket name for media storage"
  value       = module.storage.bucket_name
}

output "s3_access_key" {
  description = "S3 access key"
  value       = module.storage.s3_access_key
  sensitive   = true
}

output "s3_secret_key" {
  description = "S3 secret key"
  value       = module.storage.s3_secret_key
  sensitive   = true
}

output "queue_endpoint" {
  description = "SQS queue endpoint"
  value       = module.messaging.queue_endpoint
}

output "queue_name" {
  description = "SQS queue name"
  value       = module.messaging.queue_name
}

output "sqs_access_key" {
  description = "SQS access key"
  value       = module.messaging.sqs_access_key
  sensitive   = true
}

output "sqs_secret_key" {
  description = "SQS secret key"
  value       = module.messaging.sqs_secret_key
  sensitive   = true
}

output "bastion_ip" {
  description = "Bastion host public IP (if enabled)"
  value       = module.networking.bastion_public_ip
}

output "private_network_id" {
  description = "Private network ID"
  value       = module.networking.private_network_id
}

output "cdn_endpoint" {
  description = "CDN endpoint for media"
  value       = module.storage.cdn_endpoint
}

# DNS Outputs (if enabled)
output "api_dns_record" {
  description = "API DNS record"
  value       = var.enable_dns ? module.dns[0].api_dns_record : null
}

output "cdn_dns_record" {
  description = "CDN DNS record"
  value       = var.enable_dns ? module.dns[0].cdn_dns_record : null
}

output "www_dns_record" {
  description = "WWW DNS record"
  value       = var.enable_dns ? module.dns[0].www_dns_record : null
}