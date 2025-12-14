resource "google_secret_manager_secret" "secrets" {
  for_each  = var.secrets
  secret_id = "${var.name_prefix}-${each.key}"
  labels    = merge(var.labels, try(each.value.labels, {}))

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "versions" {
  for_each    = var.create_versions ? nonsensitive(toset(keys(var.secret_values))) : toset([])
  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = var.secret_values[each.key]
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

resource "google_secret_manager_secret_iam_member" "access" {
  for_each = {
    for b in local.accessor_bindings :
    "${b.secret}|${b.member}" => b
  }

  secret_id = google_secret_manager_secret.secrets[each.value.secret].id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}
