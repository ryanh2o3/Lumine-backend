# Container Registry
resource "scaleway_registry_namespace" "main" {
  name        = "${var.app_name}-${var.environment}"
  description = "Container registry for ${var.app_name} ${var.environment}"
  is_public   = var.registry_is_public
  region      = var.region
}

# Registry credentials for instances
data "scaleway_registry_namespace" "main" {
  namespace_id = scaleway_registry_namespace.main.id
  region       = var.region
}

# Cloud-init template for API instances
data "template_file" "cloud_init_api" {
  template = file("${path.module}/cloud-init-api.yaml")

  vars = {
    app_name          = var.app_name
    image_tag         = var.container_image_tag
    registry_endpoint = scaleway_registry_namespace.main.endpoint
    registry_password = scaleway_registry_namespace.main.id
    http_addr         = var.http_addr
    database_url      = var.database_url
    redis_url         = var.redis_url
    s3_endpoint       = var.s3_endpoint
    s3_region         = var.s3_region
    s3_bucket         = var.s3_bucket
    s3_public_endpoint = var.s3_public_endpoint
    s3_access_key     = var.s3_access_key
    s3_secret_key     = var.s3_secret_key
    queue_endpoint    = var.queue_endpoint
    queue_region      = var.queue_region
    queue_name        = var.queue_name
    sqs_access_key    = var.sqs_access_key
    sqs_secret_key    = var.sqs_secret_key
    paseto_access_key = var.paseto_access_key
    paseto_refresh_key = var.paseto_refresh_key
    admin_token       = var.admin_token
    rust_log          = var.rust_log
  }
}

# Cloud-init template for Worker instances
data "template_file" "cloud_init_worker" {
  template = file("${path.module}/cloud-init-worker.yaml")

  vars = {
    app_name          = var.app_name
    image_tag         = var.container_image_tag
    registry_endpoint = scaleway_registry_namespace.main.endpoint
    registry_password = scaleway_registry_namespace.main.id
    database_url      = var.database_url
    redis_url         = var.redis_url
    s3_endpoint       = var.s3_endpoint
    s3_region         = var.s3_region
    s3_bucket         = var.s3_bucket
    s3_public_endpoint = var.s3_public_endpoint
    s3_access_key     = var.s3_access_key
    s3_secret_key     = var.s3_secret_key
    queue_endpoint    = var.queue_endpoint
    queue_region      = var.queue_region
    queue_name        = var.queue_name
    sqs_access_key    = var.sqs_access_key
    sqs_secret_key    = var.sqs_secret_key
    rust_log          = var.rust_log
  }
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
    cloud-init = data.template_file.cloud_init_api.rendered
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
    cloud-init = data.template_file.cloud_init_worker.rendered
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
