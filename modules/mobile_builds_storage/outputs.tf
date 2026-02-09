output "bucket_name" {
  description = "The name of the GCS bucket"
  value       = google_storage_bucket.mobile_builds.name
}

output "bucket_url" {
  description = "The URL of the GCS bucket"
  value       = google_storage_bucket.mobile_builds.url
}

output "bucket_self_link" {
  description = "The self link of the GCS bucket"
  value       = google_storage_bucket.mobile_builds.self_link
}

output "base_download_url" {
  description = "The base URL for downloading mobile builds"
  value       = "https://storage.googleapis.com/${google_storage_bucket.mobile_builds.name}"
}
