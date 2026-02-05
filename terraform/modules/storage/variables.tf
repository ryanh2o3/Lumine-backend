variable "project_id" {
  description = "Scaleway project ID"
  type        = string
}

variable "region" {
  description = "Scaleway region"
  type        = string
  default     = "fr-par"
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

variable "bucket_name" {
  description = "S3 bucket name (must be globally unique)"
  type        = string
  default     = null
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = []
}

variable "cors_allowed_methods" {
  description = "CORS allowed methods"
  type        = list(string)
  default     = ["GET", "PUT", "POST", "DELETE", "HEAD"]
}

variable "cors_max_age_seconds" {
  description = "CORS max age in seconds"
  type        = number
  default     = 3600
}

variable "enable_versioning" {
  description = "Enable bucket versioning"
  type        = bool
  default     = true
}

variable "enable_glacier_transition" {
  description = "Enable transition to Glacier storage class"
  type        = bool
  default     = false
}

variable "glacier_transition_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 90
}

variable "glacier_prefix" {
  description = "Object prefix for Glacier transition"
  type        = string
  default     = "originals/"
}

variable "incomplete_multipart_days" {
  description = "Days before aborting incomplete multipart uploads"
  type        = number
  default     = 7
}

variable "enable_cdn" {
  description = "Enable CDN configuration notes"
  type        = bool
  default     = true
}

variable "cdn_custom_domain" {
  description = "Custom domain for CDN"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = list(string)
  default     = []
}
