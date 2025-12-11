resource "google_sql_database_instance" "instance" {
  name             = var.sql_instance_name
  database_version = var.sql_instance_version
  region           = var.sql_instance_region

  deletion_protection = var.sql_deletion_protection

  settings {
    tier = var.sql_tier

    backup_configuration {
      enabled                        = var.sql_backup_enabled
      start_time                     = var.sql_backup_start_time
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
    }

    availability_type = var.sql_availability_type
    ip_configuration {
      ipv4_enabled = var.sql_public_ip_enabled
      dynamic "authorized_networks" {
        for_each = var.sql_authorized_networks
        content {
          value = authorized_networks.value.value
          name  = authorized_networks.value.name
        }
      }
    }
    maintenance_window {
      day  = 7
      hour = 2
    }
    insights_config {
      query_insights_enabled = true
      query_string_length    = 1024
      record_application_tags = true
    }
  }
}

resource "google_sql_database" "database" {
  name     = var.sql_database_name
  instance = google_sql_database_instance.instance.name
}

resource "random_password" "password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_user" "user" {
  name     = var.sql_user_name
  instance = google_sql_database_instance.instance.name
  password = random_password.password.result
}

output "instance_connection_name" {
  value = google_sql_database_instance.instance.connection_name
}

output "public_ip_address" {
  value = try(google_sql_database_instance.instance.public_ip_address, null)
}

output "sql_user_password" {
  value     = random_password.password.result
  sensitive = true
}
