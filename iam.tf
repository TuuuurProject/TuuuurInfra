module "sa_app" {
  source           = "./modules/iam"
  iam_account_id   = "sa-tuuur-app"
  iam_display_name = "Tuuur App Service Account"
  iam_project_id   = module.global_settings.project_id
  iam_role         = "roles/secretmanager.secretAccessor"
}
