output "network_id" { value = google_compute_network.vpc.id }
output "network_self_link" { value = google_compute_network.vpc.self_link }

output "subnet_self_links" {
  value = { for k, s in google_compute_subnetwork.subnets : k => s.self_link }
}

output "subnet_names" {
  value = { for k, s in google_compute_subnetwork.subnets : k => s.name }
}

output "private_service_access_connection_id" {
  value = try(google_service_networking_connection.psa_connection[0].id, null)
}

output "service_networking_connection" {
  description = "Service Networking Connection for dependency management"
  value       = try(google_service_networking_connection.psa_connection[0], null)
}
