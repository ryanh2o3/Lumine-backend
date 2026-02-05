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

variable "tags" {
  description = "Tags to apply to resources"
  type        = list(string)
  default     = []
}

variable "private_network_id" {
  description = "Private network ID"
  type        = string
}

variable "ssl_certificate_ids" {
  description = "SSL certificate IDs for HTTPS termination"
  type        = list(string)
  default     = []
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

# API Gateway Configuration
variable "enable_api_gateway" {
  description = "Enable dedicated API gateway"
  type        = bool
  default     = true
}

variable "gateway_type" {
  description = "API gateway load balancer type"
  type        = string
  default     = "LB-S"
}

# IP Restrictions
variable "enable_ip_restrictions" {
  description = "Enable IP-based access restrictions"
  type        = bool
  default     = false
}

variable "allowed_ips" {
  description = "Allowed IP addresses for API access (only used if enable_ip_restrictions=true)"
  type        = list(string)
  default     = []
}

# API Keys
variable "api_keys" {
  description = "API keys for application authentication"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "enable_basic_waf" {
  description = "Enable basic L7 ACL protections on the load balancer"
  type        = bool
  default     = true
}

variable "blocked_ip_ranges" {
  description = "CIDR ranges to block at the load balancer (basic WAF/DDoS mitigation)"
  type        = list(string)
  default     = []
}

# Note: WAF, CORS, and rate limiting variables removed
# These features are not supported by Scaleway LB Terraform provider
# Implement at application level instead
