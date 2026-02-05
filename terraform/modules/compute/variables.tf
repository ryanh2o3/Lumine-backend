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
  default     = "stable"
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
variable "db_host" {
  description = "Database host (private endpoint)"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database user"
  type        = string
}

variable "db_password_secret_id" {
  description = "Secret Manager ID for database password"
  type        = string
}

variable "redis_host" {
  description = "Redis host"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_use_tls" {
  description = "Use TLS for Redis connections"
  type        = bool
  default     = false
}

variable "redis_password_secret_id" {
  description = "Secret Manager ID for Redis password"
  type        = string
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

variable "s3_access_key_secret_id" {
  description = "Secret Manager ID for S3 access key"
  type        = string
}

variable "s3_secret_key_secret_id" {
  description = "Secret Manager ID for S3 secret key"
  type        = string
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

variable "sqs_access_key_secret_id" {
  description = "Secret Manager ID for SQS access key"
  type        = string
}

variable "sqs_secret_key_secret_id" {
  description = "Secret Manager ID for SQS secret key"
  type        = string
}

variable "paseto_access_key_secret_id" {
  description = "Secret Manager ID for PASETO access key"
  type        = string
}

variable "paseto_refresh_key_secret_id" {
  description = "Secret Manager ID for PASETO refresh key"
  type        = string
}

variable "admin_token_secret_id" {
  description = "Secret Manager ID for admin token (optional)"
  type        = string
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

variable "runtime_iam_application_name" {
  description = "IAM application name for runtime instance access"
  type        = string
  default     = "ciel-runtime"
}
