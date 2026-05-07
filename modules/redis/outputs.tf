output "host" {
  value       = google_redis_instance.redis.host
  description = "Hostname or IP address of the exposed Redis endpoint"
}

output "port" {
  value       = google_redis_instance.redis.port
  description = "Port number of the exposed Redis endpoint"
}

output "id" {
  value       = google_redis_instance.redis.id
  description = "Full resource identifier (projects/*/locations/*/instances/*)"
}

output "auth_string" {
  value       = try(google_redis_instance.redis.auth_string, "")
  description = "AUTH string for the Redis instance (only if auth_enabled=true)"
  sensitive   = true
}

output "server_ca_cert_bundle" {
  value       = join("\n", [for cert in try(google_redis_instance.redis.server_ca_certs, []) : cert.cert])
  description = "PEM bundle of Redis server CA certificates"
  sensitive   = true
}

output "create_time" {
  value       = google_redis_instance.redis.create_time
  description = "Time when the instance was created"
}

output "current_location_id" {
  value       = try(google_redis_instance.redis.current_location_id, "")
  description = "Current zone where the Redis endpoint is placed"
}

output "read_endpoint" {
  value       = try(google_redis_instance.redis.read_endpoint, "")
  description = "Read endpoint for read replicas (STANDARD_HA tier only)"
}

output "read_endpoint_port" {
  value       = try(google_redis_instance.redis.read_endpoint_port, 0)
  description = "Port number of the read endpoint (STANDARD_HA tier only)"
}
