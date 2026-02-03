# Dev Environment Configuration
# This configuration uses minimal resources for development and testing

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
  environment  = "dev"
  tags         = ["environment:dev", "managed-by:terraform"]
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

  # Dev-specific settings
  enable_load_balancer  = false  # No LB needed for dev
  enable_bastion        = true   # Allow SSH access for debugging
  enable_public_gateway = true
  private_network_cidr  = "10.0.1.0/24"  # Different CIDR for dev
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

  # Dev-specific settings - minimal instances
  api_instance_count   = 1
  api_instance_type    = "DEV1-S"
  worker_instance_count = 1
  worker_instance_type = "DEV1-S"

  # Use dev container image
  container_image_tag  = "dev-latest"

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

  # Dev-specific settings - smallest database
  db_node_type        = "DB-DEV-S"
  enable_ha           = false
  volume_size_in_gb   = 5
  read_replica_count  = 0

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

  # Dev-specific settings - self-managed Redis
  use_managed_redis    = false
  redis_instance_type  = "DEV1-S"

  # Network dependencies
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

  # Dev-specific settings
  cors_allowed_origins = ["http://localhost:3000", "https://dev.ciel.example.com"]
  enable_cdn           = false  # No CDN for dev
  enable_glacier_transition = false
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

  # Dev-specific settings
  enable_dlq           = true
  message_retention_seconds = 1209600  # 14 days for dev
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

  # Dev-specific settings
  enable_alerts      = false  # No alerts for dev
}

# DNS Module (disabled for dev by default)
module "dns" {
  source = "../../modules/dns"

  count = var.enable_dns ? 1 : 0

  domain_name        = var.domain_name
  api_subdomain      = "dev-api"
  cdn_subdomain      = "dev-media"
  load_balancer_ip   = module.networking.bastion_ip  # Use bastion IP for dev
  cdn_endpoint       = module.storage.cdn_endpoint

  # Dev-specific settings
  enable_api_dns     = true
  enable_cdn_dns     = true
  enable_www_dns     = false  # No www for dev
  enable_root_dns    = false  # No root domain for dev
  enable_ssl         = false  # No SSL for dev
}