# Container Registry
resource "scaleway_registry_namespace" "main" {
  name        = "${var.app_name}-${var.environment}"
  description = "Container registry for ${var.app_name} ${var.environment}"
  is_public   = var.registry_is_public
  region      = var.region
}

# IAM application for runtime access (registry pull + secrets read)
resource "scaleway_iam_application" "runtime" {
  name        = "${var.app_name}-${var.environment}-${var.runtime_iam_application_name}"
  description = "Runtime access for ${var.app_name} ${var.environment} instances"
}

resource "scaleway_iam_policy" "runtime" {
  name           = "${var.app_name}-runtime-policy-${var.environment}"
  description    = "Registry pull and secrets read for ${var.app_name} ${var.environment}"
  application_id = scaleway_iam_application.runtime.id

  rule {
    project_ids = [var.project_id]
    permission_set_names = [
      "ContainerRegistryReadOnly",
      "SecretManagerReadOnly",
    ]
  }
}

resource "scaleway_iam_api_key" "runtime" {
  application_id = scaleway_iam_application.runtime.id
  description    = "Runtime API key for ${var.app_name} ${var.environment}"
}

# Cloud-init template for API instances
locals {
  cloud_init_api = templatefile("${path.module}/cloud-init-api.yaml", {
    app_name                   = var.app_name
    image_tag                  = var.container_image_tag
    registry_endpoint          = scaleway_registry_namespace.main.endpoint
    scw_access_key             = scaleway_iam_api_key.runtime.access_key
    scw_secret_key             = scaleway_iam_api_key.runtime.secret_key
    scw_region                 = var.region
    scw_zone                   = var.zone
    http_addr                  = var.http_addr
    db_host                    = var.db_host
    db_port                    = var.db_port
    db_name                    = var.db_name
    db_user                    = var.db_user
    db_password_secret_id      = var.db_password_secret_id
    redis_host                 = var.redis_host
    redis_port                 = var.redis_port
    redis_use_tls              = var.redis_use_tls
    redis_password_secret_id   = var.redis_password_secret_id
    s3_endpoint                = var.s3_endpoint
    s3_region                  = var.s3_region
    s3_bucket                  = var.s3_bucket
    s3_public_endpoint         = var.s3_public_endpoint
    s3_access_key_secret_id    = var.s3_access_key_secret_id
    s3_secret_key_secret_id    = var.s3_secret_key_secret_id
    queue_endpoint             = var.queue_endpoint
    queue_region               = var.queue_region
    queue_name                 = var.queue_name
    sqs_access_key_secret_id   = var.sqs_access_key_secret_id
    sqs_secret_key_secret_id   = var.sqs_secret_key_secret_id
    paseto_access_key_secret_id  = var.paseto_access_key_secret_id
    paseto_refresh_key_secret_id = var.paseto_refresh_key_secret_id
    admin_token_secret_id        = var.admin_token_secret_id
    rust_log                   = var.rust_log
  })
}

# Cloud-init template for Worker instances
locals {
  cloud_init_worker = templatefile("${path.module}/cloud-init-worker.yaml", {
    app_name                   = var.app_name
    image_tag                  = var.container_image_tag
    registry_endpoint          = scaleway_registry_namespace.main.endpoint
    scw_access_key             = scaleway_iam_api_key.runtime.access_key
    scw_secret_key             = scaleway_iam_api_key.runtime.secret_key
    scw_region                 = var.region
    scw_zone                   = var.zone
    db_host                    = var.db_host
    db_port                    = var.db_port
    db_name                    = var.db_name
    db_user                    = var.db_user
    db_password_secret_id      = var.db_password_secret_id
    redis_host                 = var.redis_host
    redis_port                 = var.redis_port
    redis_use_tls              = var.redis_use_tls
    redis_password_secret_id   = var.redis_password_secret_id
    s3_endpoint                = var.s3_endpoint
    s3_region                  = var.s3_region
    s3_bucket                  = var.s3_bucket
    s3_public_endpoint         = var.s3_public_endpoint
    s3_access_key_secret_id    = var.s3_access_key_secret_id
    s3_secret_key_secret_id    = var.s3_secret_key_secret_id
    queue_endpoint             = var.queue_endpoint
    queue_region               = var.queue_region
    queue_name                 = var.queue_name
    sqs_access_key_secret_id   = var.sqs_access_key_secret_id
    sqs_secret_key_secret_id   = var.sqs_secret_key_secret_id
    rust_log                   = var.rust_log
  })
}

# API Instances
resource "scaleway_instance_server" "api" {
  count = var.api_instance_count

  name  = "${var.app_name}-api-${var.environment}-${count.index + 1}"
  type  = var.api_instance_type
  image = "debian_bookworm"
  zone  = var.zone

  security_group_id = var.api_security_group_id

  private_network {
    pn_id = var.private_network_id
  }

  user_data = {
    cloud-init = local.cloud_init_api
  }

  tags = concat(var.tags, [
    "environment:${var.environment}",
    "role:api",
    "app:${var.app_name}"
  ])

  lifecycle {
    create_before_destroy = true
  }
}

# Register API instances with load balancer
resource "scaleway_lb_backend_server" "api" {
  count = var.load_balancer_backend_id != null ? var.api_instance_count : 0

  backend_id = var.load_balancer_backend_id
  ip         = scaleway_instance_server.api[count.index].private_ip
}

# Worker Instances
resource "scaleway_instance_server" "worker" {
  count = var.worker_instance_count

  name  = "${var.app_name}-worker-${var.environment}-${count.index + 1}"
  type  = var.worker_instance_type
  image = "debian_bookworm"
  zone  = var.zone

  security_group_id = var.worker_security_group_id

  private_network {
    pn_id = var.private_network_id
  }

  user_data = {
    cloud-init = local.cloud_init_worker
  }

  tags = concat(var.tags, [
    "environment:${var.environment}",
    "role:worker",
    "app:${var.app_name}"
  ])

  lifecycle {
    create_before_destroy = true
  }
}
