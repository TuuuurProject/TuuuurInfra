output "id" { value = google_cloud_run_v2_service.service.id }
output "uri" { value = google_cloud_run_v2_service.service.uri }

# Nom court (pour serverless NEG cloud_run.service)
output "service_id" { value = var.name }
