output "queue_name" {
  description = "SQS queue name"
  value       = scaleway_mnq_sqs_queue.main.name
}

output "queue_url" {
  description = "SQS queue URL"
  value       = scaleway_mnq_sqs_queue.main.url
}

output "queue_endpoint" {
  description = "SQS endpoint URL"
  value       = scaleway_mnq_sqs.main.endpoint
}

output "queue_region" {
  description = "SQS queue region"
  value       = var.region
}

output "sqs_access_key" {
  description = "SQS access key"
  value       = scaleway_mnq_sqs_credentials.main.access_key
  sensitive   = true
}

output "sqs_secret_key" {
  description = "SQS secret key"
  value       = scaleway_mnq_sqs_credentials.main.secret_key
  sensitive   = true
}

output "dlq_name" {
  description = "Dead letter queue name"
  value       = var.enable_dlq ? scaleway_mnq_sqs_queue.dlq[0].name : null
}

output "dlq_url" {
  description = "Dead letter queue URL"
  value       = var.enable_dlq ? scaleway_mnq_sqs_queue.dlq[0].url : null
}
