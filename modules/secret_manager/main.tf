resource "google_secret_manager_secret" "secret" {
  secret_id = var.secret_name

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "version" {
  secret      = google_secret_manager_secret.secret.id
  secret_data = var.secret_value
}
