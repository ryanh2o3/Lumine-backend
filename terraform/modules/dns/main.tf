# DNS Module for Scaleway
# Manages domain records and SSL certificates

# Domain records for API
resource "scaleway_domain_record" "api" {
  count = var.enable_api_dns ? 1 : 0

  dns_zone = var.domain_name
  name     = var.api_subdomain
  type     = "A"
  data     = var.load_balancer_ip
  ttl      = 300
  priority = null
}

# Domain records for CDN/media
resource "scaleway_domain_record" "cdn" {
  count = var.enable_cdn_dns ? 1 : 0

  dns_zone = var.domain_name
  name     = var.cdn_subdomain
  type     = "CNAME"
  data     = var.cdn_endpoint
  ttl      = 300
  priority = null
}

# Domain records for main website
resource "scaleway_domain_record" "www" {
  count = var.enable_www_dns ? 1 : 0

  dns_zone = var.domain_name
  name     = "www"
  type     = "A"
  data     = var.load_balancer_ip
  ttl      = 300
  priority = null
}

# Domain records for root domain
resource "scaleway_domain_record" "root" {
  count = var.enable_root_dns ? 1 : 0

  dns_zone = var.domain_name
  name     = "@"
  type     = "A"
  data     = var.load_balancer_ip
  ttl      = 300
  priority = null
}

# SSL Certificate for domain (using Let's Encrypt)
resource "scaleway_domain_certificate" "ssl" {
  count = var.enable_ssl ? 1 : 0

  dns_zone = var.domain_name
  type     = "lets_encrypt"
  subject  = "*.${var.domain_name}"
  subject_alternative_names = [
    var.domain_name,
    "www.${var.domain_name}",
    "${var.api_subdomain}.${var.domain_name}",
    "${var.cdn_subdomain}.${var.domain_name}"
  ]
  auto_renew = true
}

# DNS verification for SSL certificate
resource "scaleway_domain_record" "ssl_verification" {
  count = var.enable_ssl && length(scaleway_domain_certificate.ssl) > 0 ? 1 : 0

  dns_zone = var.domain_name
  name     = scaleway_domain_certificate.ssl[0].dns_challenge_record_name
  type     = "TXT"
  data     = scaleway_domain_certificate.ssl[0].dns_challenge_record_value
  ttl      = 300
  priority = null
}