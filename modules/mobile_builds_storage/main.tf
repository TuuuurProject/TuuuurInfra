resource "google_storage_bucket" "mobile_builds" {
  name          = var.bucket_name
  location      = var.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  lifecycle_rule {
    condition {
      age            = 90
      matches_prefix = ["mobile/"]
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    purpose     = "mobile-builds"
  }
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.mobile_builds.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket_object" "android_folder" {
  name    = "mobile/android/.keep"
  content = "# Android builds folder"
  bucket  = google_storage_bucket.mobile_builds.name
}

resource "google_storage_bucket_object" "ios_folder" {
  name    = "mobile/ios/.keep"
  content = "# iOS builds folder"
  bucket  = google_storage_bucket.mobile_builds.name
}
