variable "project_id" {
  description = "Scaleway project ID"
  type        = string
}

variable "region" {
  description = "Scaleway region"
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
  default     = "fr-par-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "ciel"
}

# Container Registry
variable "registry_is_public" {
  description = "Whether the container registry is public"
  type        = bool
  default     = false
}

# API Instances
variable "api_instance_count" {
  description = "Number of API instances"
  type        = number
  default     = 1
}

variable "api_instance_type" {
  description = "API instance type"
  type        = string
  default     = "DEV1-S"
}

# Worker Instances
variable "worker_instance_count" {
  description = "Number of worker instances"
  type        = number
  default     = 1
}

variable "worker_instance_type" {
  description = "Worker instance type"
  type        = string
  default     = "DEV1-S"
}

# Container Image
variable "container_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# Network
variable "private_network_id" {
  description = "Private network ID"
  type        = string
}

variable "api_security_group_id" {
  description = "API security group ID"
  type        = string
}

variable "worker_security_group_id" {
  description = "Worker security group ID"
  type        = string
}

variable "load_balancer_backend_id" {
  description = "Load balancer backend ID for registering API instances"
  type        = string
  default     = null
}

# Environment Variables
variable "database_url" {
  description = "Database connection URL"
  type        = string
  sensitive   = true
}

variable "redis_url" {
  description = "Redis connection URL"
  type        = string
  sensitive   = true
}

variable "s3_endpoint" {
  description = "S3 endpoint URL"
  type        = string
}

variable "s3_region" {
  description = "S3 region"
  type        = string
  default     = "fr-par"
}

variable "s3_bucket" {
  description = "S3 bucket name"
  type        = string
}

variable "s3_public_endpoint" {
  description = "S3 public/CDN endpoint for serving media"
  type        = string
}

variable "s3_access_key" {
  description = "S3 access key"
  type        = string
  sensitive   = true
}

variable "s3_secret_key" {
  description = "S3 secret key"
  type        = string
  sensitive   = true
}

variable "queue_endpoint" {
  description = "SQS queue endpoint"
  type        = string
}

variable "queue_region" {
  description = "SQS queue region"
  type        = string
  default     = "fr-par"
}

variable "queue_name" {
  description = "SQS queue name"
  type        = string
}

variable "sqs_access_key" {
  description = "SQS access key"
  type        = string
  sensitive   = true
}

variable "sqs_secret_key" {
  description = "SQS secret key"
  type        = string
  sensitive   = true
}

variable "paseto_access_key" {
  description = "PASETO access token key (base64 encoded 32 bytes)"
  type        = string
  sensitive   = true
}

variable "paseto_refresh_key" {
  description = "PASETO refresh token key (base64 encoded 32 bytes)"
  type        = string
  sensitive   = true
}

variable "admin_token" {
  description = "Admin API token (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "http_addr" {
  description = "HTTP listen address"
  type        = string
  default     = "0.0.0.0:8080"
}

variable "rust_log" {
  description = "Rust log level"
  type        = string
  default     = "info"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = list(string)
  default     = []
}
