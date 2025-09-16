resource "google_compute_health_check" "hc" {
  name = "${var.name}-hc"
  http_health_check {
    port = 80
    request_path = "/health"
  }
}

resource "google_compute_backend_service" "frontend" {
  name        = "${var.name}-frontend-bs"
  protocol    = "HTTP"
  port_name   = "http"
  health_checks = [google_compute_health_check.hc.id]
  backend { group = var.frontend_group }
}

resource "google_compute_backend_service" "backend" {
  name        = "${var.name}-backend-bs"
  protocol    = "HTTP"
  port_name   = "http"
  health_checks = [google_compute_health_check.hc.id]
  backend { group = var.backend_group }
}

resource "google_compute_url_map" "map" {
  name = "${var.name}-url-map"
  default_service = google_compute_backend_service.frontend.id

  host_rule {
    hosts = ["*"]
    path_matcher = "allpaths"
  }
  path_matcher {
    name = "allpaths"
    default_service = google_compute_backend_service.frontend.id

    path_rule {
      paths = ["/api/*"]
      service = google_compute_backend_service.backend.id
    }
  }
}

resource "google_compute_target_http_proxy" "proxy" {
  name    = "${var.name}-proxy"
  url_map = google_compute_url_map.map.id
}

resource "google_compute_global_address" "ip" {
  name = "${var.name}-ip"
}

resource "google_compute_global_forwarding_rule" "fr" {
  name       = "${var.name}-fr"
  target     = google_compute_target_http_proxy.proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.ip.address
}

output "ip" {
  value = google_compute_global_address.ip.address
}
