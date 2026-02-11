resource "google_redis_instance" "redis" {
  name               = "${var.name_prefix}-redis"
  region             = var.region
  tier               = var.tier
  memory_size_gb     = var.memory_size_gb
  redis_version      = var.redis_version
  authorized_network = var.network_id

  depends_on = [var.service_networking_connection]

  auth_enabled            = var.auth_enabled
  transit_encryption_mode = var.transit_encryption_mode

  labels = var.labels
}

resource "google_secret_manager_secret_version" "redis_auth" {
  count       = var.auth_enabled ? 1 : 0
  secret      = var.redis_auth_secret_id
  secret_data = google_redis_instance.redis.auth_string

  lifecycle {
    ignore_changes = [secret_data]
  }
}
