# Production Environment Configuration
# This configuration uses production-grade resources with high availability

terraform {
  required_version = ">= 1.5.0"
}

# Configure the Scaleway provider
provider "scaleway" {
  zone       = var.zone
  region     = var.region
  project_id = var.project_id
}

# Shared variables
locals {
  app_name     = "ciel"
  environment  = "prod"
  tags         = ["environment:prod", "managed-by:terraform"]
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  project_id            = var.project_id
  region                = var.region
  zone                  = var.zone
  environment           = local.environment
  app_name              = local.app_name
  tags                  = local.tags

  # Production-specific settings
  enable_load_balancer  = true
  enable_bastion        = false  # No bastion in production for security
  enable_public_gateway = true
  private_network_cidr  = "10.0.3.0/24"  # Different CIDR for prod
  lb_type               = "LB-GP-S"  # General purpose load balancer
  ssl_certificate_ids  = var.enable_dns ? module.dns[0].ssl_certificate_ids : []
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  project_id           = var.project_id
  region               = var.region
  zone                 = var.zone
  environment          = local.environment
  app_name             = local.app_name
  tags                 = local.tags

  # Production-specific settings - multiple instances for HA
  api_instance_count   = 2
  api_instance_type    = "DEV1-M"
  worker_instance_count = 2
  worker_instance_type = "DEV1-S"

  # Use production container image with version tag
  container_image_tag  = "v1.0.0"  # Use semantic versioning

  # Network dependencies
  private_network_id   = module.networking.private_network_id
  api_security_group_id = module.networking.api_security_group_id
  worker_security_group_id = module.networking.worker_security_group_id
}

# Database Module
module "database" {
  source = "../../modules/database"

  project_id          = var.project_id
  region              = var.region
  zone                = var.zone
  environment         = local.environment
  app_name            = local.app_name
  tags                = local.tags

  # Production-specific settings - HA database
  db_node_type        = "DB-PRO2-XXS"
  enable_ha           = true
  volume_size_in_gb   = 50
  read_replica_count  = 1  # Read replica for scaling

  # Database credentials
  db_admin_password   = var.db_admin_password
  db_user_password    = var.db_user_password
}

# Cache Module
module "cache" {
  source = "../../modules/cache"

  project_id           = var.project_id
  region               = var.region
  zone                 = var.zone
  environment          = local.environment
  app_name             = local.app_name
  tags                 = local.tags

  # Production-specific settings - managed Redis for reliability
  use_managed_redis    = true
  managed_redis_node_type = "RED1-micro"

  # Network dependencies (only needed for self-managed)
  private_network_id    = module.networking.private_network_id
  redis_security_group_id = module.networking.redis_security_group_id
}

# Storage Module
module "storage" {
  source = "../../modules/storage"

  project_id          = var.project_id
  region              = var.region
  zone                = var.zone
  environment         = local.environment
  app_name            = local.app_name
  tags                = local.tags

  # Production-specific settings
  cors_allowed_origins = ["https://ciel.example.com", "https://www.ciel.example.com"]
  enable_cdn           = true
  enable_glacier_transition = true  # Move old files to glacier
}

# Messaging Module
module "messaging" {
  source = "../../modules/messaging"

  project_id          = var.project_id
  region              = var.region
  zone                = var.zone
  environment         = local.environment
  app_name            = local.app_name
  tags                = local.tags

  # Production-specific settings
  enable_dlq           = true
  message_retention_seconds = 345600  # 4 days
}

# Secrets Module
module "secrets" {
  source = "../../modules/secrets"

  project_id         = var.project_id
  region             = var.region
  zone               = var.zone
  environment        = local.environment
  app_name           = local.app_name
  tags               = local.tags

  # Secrets from variables
  paseto_access_key  = var.paseto_access_key
  paseto_refresh_key = var.paseto_refresh_key
  admin_token        = var.admin_token
}

# Observability Module
module "observability" {
  source = "../../modules/observability"

  project_id         = var.project_id
  region             = var.region
  zone               = var.zone
  environment        = local.environment
  app_name           = local.app_name
  tags               = local.tags

  # Production-specific settings
  enable_alerts      = true
}

# DNS Module
module "dns" {
  source = "../../modules/dns"

  count = var.enable_dns ? 1 : 0

  domain_name        = var.domain_name
  api_subdomain      = "api"
  cdn_subdomain      = "media"
  load_balancer_ip   = module.networking.load_balancer_ip
  cdn_endpoint       = module.storage.cdn_endpoint

  # Production-specific settings
  enable_api_dns     = true
  enable_cdn_dns     = true
  enable_www_dns     = true
  enable_root_dns    = true  # Use root domain for production
  enable_ssl         = true   # Enable SSL for production
}