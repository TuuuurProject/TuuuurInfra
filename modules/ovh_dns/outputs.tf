output "record_id" {
  value       = ovh_domain_zone_record.record.id
  description = "ID de l'enregistrement DNS OVH"
}

output "fqdn" {
  value       = "${var.subdomain}.${var.domain}"
  description = "FQDN complet"
}
