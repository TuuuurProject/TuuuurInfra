resource "google_redis_instance" "redis" {
  name               = "${var.name_prefix}-redis"
  region             = var.region
  tier               = var.tier
  memory_size_gb     = var.memory_size_gb
  redis_version      = var.redis_version
  authorized_network = var.network_id

  # Force destruction avant Service Networking Connection
  depends_on = [var.service_networking_connection]

  auth_enabled            = var.auth_enabled
  transit_encryption_mode = var.transit_encryption_mode

  labels = var.labels
}
