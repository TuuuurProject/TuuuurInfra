output "instance_name" {
  value = try(google_sql_database_instance.sql[0].name, null)
}

output "private_ip_address" {
  value = try(google_sql_database_instance.sql[0].private_ip_address, null)
}
