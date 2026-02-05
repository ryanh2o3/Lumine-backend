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

# Self-managed vs Managed Redis
variable "use_managed_redis" {
  description = "Use Scaleway managed Redis instead of self-managed"
  type        = bool
  default     = false
}

# Self-managed Redis settings
variable "redis_instance_type" {
  description = "Instance type for self-managed Redis"
  type        = string
  default     = "DEV1-S"
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

# Managed Redis settings
variable "managed_redis_node_type" {
  description = "Node type for managed Redis"
  type        = string
  default     = "RED1-micro"
}

variable "managed_redis_version" {
  description = "Redis version for managed instance"
  type        = string
  default     = "7.0.12"
}

variable "managed_redis_cluster_size" {
  description = "Number of nodes in managed Redis cluster"
  type        = number
  default     = 2
}

variable "managed_redis_tls_enabled" {
  description = "Enable TLS for managed Redis"
  type        = bool
  default     = true
}

# Network
variable "private_network_id" {
  description = "Private network ID"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for self-managed Redis"
  type        = string
}

# Redis configuration
variable "redis_maxmemory_policy" {
  description = "Redis maxmemory eviction policy"
  type        = string
  default     = "allkeys-lru"
}

variable "redis_maxmemory_mb" {
  description = "Redis max memory in MB (for self-managed)"
  type        = number
  default     = 256
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = list(string)
  default     = []
}
