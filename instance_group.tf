resource "google_compute_instance_group_manager" "backend_mig" {
  name               = "tuuur-backend-mig"
  base_instance_name = "tuuur-backend"
  zone               = "${module.global_settings.region}-b"
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.backend_template.self_link
    name              = "v1"
  }

  named_port {
    name = "http"
    port = 8080
  }
}

resource "google_compute_instance_group_manager" "frontend_mig" {
  name               = "tuuur-frontend-mig"
  base_instance_name = "tuuur-frontend"
  zone               = "${module.global_settings.region}-b"
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.frontend_template.self_link
    name              = "v1"
  }

  named_port {
    name = "http"
    port = 80
  }
}
