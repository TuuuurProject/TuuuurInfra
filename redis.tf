module "redis" {
  source = "./modules/redis"

  name       = "tuuur-cache"
  project_id = module.global_settings.project_id
  region     = module.global_settings.region
  size_gb    = 5
  tier       = "BASIC"
  redis_version = "7.2"
}

# Stocker le token AUTH du Redis dans Secret Manager
module "redis_auth_secret" {
  source       = "./modules/secret_manager"
  secret_name  = "tuuur-redis-auth"
  secret_value = module.redis.auth_string
  labels       = { app = "tuuur", component = "cache" }
}
