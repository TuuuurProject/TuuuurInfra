resource "google_compute_global_address" "ip" {
  name = "${var.name_prefix}-lb-ip"
}

# Un certificat SSL par domaine (Google ne permet pas de mettre à jour un certificat en place)
resource "google_compute_managed_ssl_certificate" "certs" {
  for_each = toset(var.domains)

  name = "${var.name_prefix}-cert-${replace(replace(each.value, ".", "-"), "*", "wildcard")}"
  managed {
    domains = [each.value]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_network_endpoint_group" "neg" {
  name                  = "${var.name_prefix}-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service
  }
}

resource "google_compute_backend_service" "backend" {
  name                  = "${var.name_prefix}-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  backend {
    group = google_compute_region_network_endpoint_group.neg.id
  }
}

resource "google_compute_url_map" "https" {
  name            = "${var.name_prefix}-urlmap"
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_target_https_proxy" "https" {
  name             = "${var.name_prefix}-https-proxy"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [for cert in google_compute_managed_ssl_certificate.certs : cert.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name_prefix}-https-fr"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "443"
  ip_address            = google_compute_global_address.ip.address
  target                = google_compute_target_https_proxy.https.id
}

# HTTP -> HTTPS redirect
resource "google_compute_url_map" "http_redirect" {
  name = "${var.name_prefix}-http-redirect"
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "http" {
  name    = "${var.name_prefix}-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name_prefix}-http-fr"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "80"
  ip_address            = google_compute_global_address.ip.address
  target                = google_compute_target_http_proxy.http.id
}

# DNS A record(s) optionnel (Cloud DNS zone existante)
data "google_dns_managed_zone" "zone" {
  count = var.create_dns_records ? 1 : 0
  name  = var.dns_zone_name
}

resource "google_dns_record_set" "a_records" {
  for_each = var.create_dns_records ? toset(var.domains) : toset([])

  managed_zone = data.google_dns_managed_zone.zone[0].name
  name         = "${each.value}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.ip.address]
}
