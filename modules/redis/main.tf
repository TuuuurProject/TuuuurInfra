resource "google_redis_instance" "redis" {
  name               = "${var.name_prefix}-redis"
  region             = var.region
  tier               = var.tier
  memory_size_gb     = var.memory_size_gb
  redis_version      = var.redis_version
  authorized_network = var.network_id

  depends_on = [var.service_networking_connection]

  # Network and connection settings
  connect_mode            = var.connect_mode
  reserved_ip_range       = var.reserved_ip_range
  location_id             = var.location_id
  alternative_location_id = var.alternative_location_id

  # Display and metadata
  display_name = var.display_name != "" ? var.display_name : "${var.name_prefix} Redis Instance"
  labels       = var.labels

  # Auth and encryption
  auth_enabled            = var.auth_enabled
  transit_encryption_mode = var.transit_encryption_mode

  # HA and replication (for STANDARD_HA)
  replica_count      = var.tier == "STANDARD_HA" ? (var.replica_count != null ? var.replica_count : 1) : null
  read_replicas_mode = var.tier == "STANDARD_HA" ? var.read_replicas_mode : null

  # Persistence
  dynamic "persistence_config" {
    for_each = var.persistence_enabled ? [1] : []
    content {
      persistence_mode    = "RDB"
      rdb_snapshot_period = var.persistence_rdb_snapshot_period
    }
  }

  # Extended timeouts for destruction
  timeouts {
    create = "30m"
    update = "30m"
    delete = "45m"
  }
}


