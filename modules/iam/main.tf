resource "google_service_account" "sa" {
  account_id   = var.iam_account_id
  display_name = var.iam_display_name
}

resource "google_project_iam_member" "member" {
  project = var.iam_project_id
  role    = var.iam_role
  member  = "serviceAccount:${google_service_account.sa.email}"
}
