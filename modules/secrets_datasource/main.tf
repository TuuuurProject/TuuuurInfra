data "google_secret_manager_secret_version" "secrets" {
  for_each = toset(var.secret_names)
  secret   = "${var.name_prefix}-${each.key}"
  project  = var.project_id
}

locals {
  secrets_map = {
    for name in var.secret_names :
    name => data.google_secret_manager_secret_version.secrets[name].secret_data
  }
}
