resource "google_secret_manager_secret_iam_member" "access" {
  for_each = {
    for binding in local.accessor_bindings :
    "${binding.secret}|${binding.member}" => binding
  }

  project   = var.project_id
  secret_id = "${var.name_prefix}-${each.value.secret}"
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}

locals {
  accessor_bindings = flatten([
    for s, members in var.accessors : [
      for m in members : {
        secret = s
        member = m
      }
    ]
  ])
}
