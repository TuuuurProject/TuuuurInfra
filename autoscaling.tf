resource "google_compute_autoscaler" "backend_as" {
  name   = "tuuur-backend-autoscaler"
  zone   = google_compute_instance_group_manager.backend_mig.zone
  target = google_compute_instance_group_manager.backend_mig.id

  autoscaling_policy {
    min_replicas    = 1
    max_replicas    = 10
    cooldown_period = 60
    cpu_utilization {
      target = 0.6
    }
  }
}

resource "google_compute_autoscaler" "frontend_as" {
  name   = "tuuur-frontend-autoscaler"
  zone   = google_compute_instance_group_manager.frontend_mig.zone
  target = google_compute_instance_group_manager.frontend_mig.id

  autoscaling_policy {
    min_replicas    = 2
    max_replicas    = 10
    cooldown_period = 60
    cpu_utilization {
      target = 0.6
    }
  }
}
