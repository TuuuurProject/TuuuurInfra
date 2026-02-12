output "secrets" {
  value       = local.secrets_map
  sensitive   = true
  description = "Map of secret names to their values (sensitive)"
}

output "config" {
  value = {
    for name, value in local.secrets_map :
    name => nonsensitive(value)
    if contains([
      "region",
      "front-domain",
      "api-domain",
      "ovh-domain"
    ], name)
  }
  sensitive   = false
  description = "Map of non-sensitive configuration values"
}

output "secret_versions" {
  value = {
    for name in var.secret_names :
    name => data.google_secret_manager_secret_version.secrets[name].version
  }
  description = "Map of secret names to their version numbers"
}
