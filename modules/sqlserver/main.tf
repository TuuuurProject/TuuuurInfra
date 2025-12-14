locals {
  use_cloudsql = var.mode == "cloudsql"
  use_vm       = var.mode == "vm"
}

# -------- Cloud SQL for SQL Server (Private IP) --------
resource "google_sql_database_instance" "sql" {
  count            = local.use_cloudsql ? 1 : 0
  name             = "${var.name_prefix}-sql"
  region           = var.region
  database_version = var.database_version
  root_password    = var.root_password

  settings {
    tier              = var.tier
    availability_type = var.high_availability ? "REGIONAL" : "ZONAL"
    disk_size         = var.disk_size_gb
    disk_type         = var.disk_type

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_self_link
    }

    backup_configuration {
      enabled = true
    }

    user_labels = var.labels
  }

  deletion_protection = false
}

resource "google_sql_database" "db" {
  count    = local.use_cloudsql ? 1 : 0
  name     = var.db_name
  instance = google_sql_database_instance.sql[0].name
}

resource "google_sql_user" "user" {
  count    = local.use_cloudsql ? 1 : 0
  name     = var.db_user
  instance = google_sql_database_instance.sql[0].name
  password = var.db_password
}

# -------- VM SQL Server fallback (Compute Engine) --------
resource "google_compute_instance" "sql_vm" {
  count        = local.use_vm ? 1 : 0
  name         = "${var.name_prefix}-sql-vm"
  zone         = var.vm_zone
  machine_type = var.vm_machine_type
  tags         = ["${var.name_prefix}-sqlserver"]

  boot_disk {
    initialize_params {
      image = var.vm_image
      size  = var.vm_boot_disk_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.vm_subnet_self_link
    # pas d'access_config => pas d'IP publique
  }

  labels = var.labels
}

resource "google_compute_firewall" "sql_vm_1433" {
  count     = local.use_vm ? 1 : 0
  name      = "${var.name_prefix}-allow-sqlserver-1433"
  network   = var.network_id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = var.allowed_source_ranges
  target_tags   = ["${var.name_prefix}-sqlserver"]

  allow {
    protocol = "tcp"
    ports    = ["1433"]
  }
}
