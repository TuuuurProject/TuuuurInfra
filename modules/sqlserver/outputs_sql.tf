output "db_setup_job_name" {
  description = "Nom du Cloud Run Job de setup utilisateur"
  value       = local.use_cloudsql && var.run_migration && var.migration_image != "" ? google_cloud_run_v2_job.db_setup[0].name : "N/A"
}

output "migration_job_name" {
  description = "Nom du Cloud Run Job de migration"
  value       = local.use_cloudsql && var.run_migration && var.migration_image != "" ? google_cloud_run_v2_job.db_migration[0].name : "N/A"
}

output "migration_job_url" {
  description = "URL console du Cloud Run Job de migration"
  value       = local.use_cloudsql && var.run_migration && var.migration_image != "" ? "https://console.cloud.google.com/run/jobs/details/${var.region}/${google_cloud_run_v2_job.db_migration[0].name}?project=${var.project_id}" : "N/A"
}

output "run_setup_command" {
  description = "Commande pour ré-exécuter manuellement le setup utilisateur"
  value       = local.use_cloudsql && var.run_migration && var.migration_image != "" ? "gcloud run jobs execute ${google_cloud_run_v2_job.db_setup[0].name} --region=${var.region} --project=${var.project_id} --wait" : "N/A"
}

output "run_migration_command" {
  description = "Commande pour ré-exécuter manuellement la migration"
  value       = local.use_cloudsql && var.run_migration && var.migration_image != "" ? "gcloud run jobs execute ${google_cloud_run_v2_job.db_migration[0].name} --region=${var.region} --project=${var.project_id} --wait" : "N/A"
}

output "run_full_migration_command" {
  description = "Commande pour ré-exécuter le setup ET la migration"
  value       = local.use_cloudsql && var.run_migration && var.migration_image != "" ? "gcloud run jobs execute ${google_cloud_run_v2_job.db_setup[0].name} --region=${var.region} --project=${var.project_id} --wait && gcloud run jobs execute ${google_cloud_run_v2_job.db_migration[0].name} --region=${var.region} --project=${var.project_id} --wait" : "N/A"
}
