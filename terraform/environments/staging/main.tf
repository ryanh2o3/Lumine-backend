# Staging Environment Configuration
# This configuration mirrors production but with smaller resources

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
  environment  = "staging"
  tags         = ["environment:staging", "managed-by:terraform"]
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

  # Staging-specific settings
  enable_load_balancer  = true  # Use load balancer for staging
  enable_bastion        = true   # Allow SSH access for debugging
  enable_public_gateway = true
  private_network_cidr  = "10.0.2.0/24"  # Different CIDR for staging
  lb_type               = "LB-S"
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

  # Staging-specific settings - slightly larger than dev
  api_instance_count   = 2
  api_instance_type    = "DEV1-S"
  worker_instance_count = 1
  worker_instance_type = "DEV1-S"

  # Use staging container image
  container_image_tag  = "staging-latest"

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

  # Staging-specific settings
  db_node_type        = "DB-DEV-S"
  enable_ha           = false
  volume_size_in_gb   = 10
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

  # Staging-specific settings - self-managed Redis
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

  # Staging-specific settings
  cors_allowed_origins = ["https://staging.ciel.example.com"]
  enable_cdn           = true  # Enable CDN for staging
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

  # Staging-specific settings
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

  # Staging-specific settings
  enable_alerts      = true  # Enable alerts for staging
}

# DNS Module
module "dns" {
  source = "../../modules/dns"

  count = var.enable_dns ? 1 : 0

  domain_name        = var.domain_name
  api_subdomain      = "staging-api"
  cdn_subdomain      = "staging-media"
  load_balancer_ip   = module.networking.load_balancer_ip
  cdn_endpoint       = module.storage.cdn_endpoint

  # Staging-specific settings
  enable_api_dns     = true
  enable_cdn_dns     = true
  enable_www_dns     = true
  enable_root_dns    = false  # Use staging subdomain only
  enable_ssl         = true   # Enable SSL for staging
}