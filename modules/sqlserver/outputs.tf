output "instance_name" {
  value = var.mode == "cloudsql" ? try(google_sql_database_instance.sql[0].name, null) : try(google_compute_instance.sql_vm[0].name, null)
}

output "private_ip_address" {
  value = var.mode == "cloudsql" ? try(google_sql_database_instance.sql[0].private_ip_address, null) : try(google_compute_instance.sql_vm[0].network_interface[0].network_ip, null)
}
