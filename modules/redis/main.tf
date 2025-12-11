resource "google_redis_instance" "redis" {
  name           = var.name
  tier           = var.tier
  memory_size_gb = var.size_gb
  region         = var.region
  redis_version  = var.redis_version
  location_id    = "${var.region}-a"
  project        = var.project_id

  auth_enabled = true

  maintenance_policy {
    weekly_maintenance_window {
      day      = "SUNDAY"
      start_time {
        hours   = 2
        minutes = 0
      }
    }
  }
}

output "host" {
  value = google_redis_instance.redis.host
}

output "port" {
  value = google_redis_instance.redis.port
}

output "auth_string" {
  value     = google_redis_instance.redis.auth_string
  sensitive = true
}
