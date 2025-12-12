output "front_lb_ip"      { value = module.lb_front.ip_address }
output "api_lb_ip"        { value = module.lb_api.ip_address }
output "front_url"        { value = "https://${var.front_domain}" }
output "api_url"          { value = "https://${var.api_domain}" }

output "redis_host"       { value = module.redis.host }
output "redis_port"       { value = module.redis.port }

output "sql_private_ip"   { value = module.sql.private_ip_address }
output "sql_instance_name"{ value = module.sql.instance_name }

output "bastion_name"     { value = module.bastion.name }
output "bastion_zone"     { value = var.bastion_zone }
