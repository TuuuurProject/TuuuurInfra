locals {
  prefix = "${var.app_name}-${var.env}"
  labels = merge(var.labels, {
    app = var.app_name
    env = var.env
  })
}

module "project_services" {
  source     = "../../modules/project_services"
  project_id = var.project_id
}

# Service Accounts Cloud Run (minimal)
resource "google_service_account" "run_front" {
  account_id   = "${local.prefix}-front"
  display_name = "${local.prefix} Cloud Run Front"
}

resource "google_service_account" "run_api" {
  account_id   = "${local.prefix}-api"
  display_name = "${local.prefix} Cloud Run API"
}

module "network" {
  source      = "../../modules/network"
  project_id  = var.project_id
  name_prefix = local.prefix
  labels      = local.labels

  subnets = {
    app = {
      cidr                  = var.app_subnet_cidr
      region                = var.region
      private_google_access = true
    }
    admin = {
      cidr                  = var.admin_subnet_cidr
      region                = var.region
      private_google_access = true
    }
    connector = {
      cidr                  = var.connector_cidr
      region                = var.region
      private_google_access = true
    }
  }

  bastion_network_tags                 = ["${local.prefix}-bastion"]
  enable_private_service_access        = true
  private_service_access_prefix_length = 16
}

# Serverless VPC Access connector (pour API)
module "vpc_connector" {
  source      = "../../modules/vpc_connector"
  project_id  = var.project_id
  name_prefix = local.prefix
  region      = var.region

  subnet_name = module.network.subnet_names["connector"]

  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
}

# Secrets (création des secrets + IAM)
module "secrets" {
  source      = "../../modules/secrets"
  project_id  = var.project_id
  name_prefix = local.prefix
  labels      = local.labels

  secrets = {
    db-password = { labels = local.labels }
    redis-auth  = { labels = local.labels }
  }

  # ⚠️ Optionnel: laisser Terraform créer des versions avec des valeurs (les valeurs seront dans le state).
  create_versions = true
  secret_values = {
    db-password = var.db_password
    redis-auth  = var.redis_auth ? module.redis.auth_string : "unused" # exemple: réutilise, à remplacer
  }

  # Runtime SA : accès lecture secrets nécessaires
  accessors = {
    db-password = ["serviceAccount:${google_service_account.run_api.email}"]
    redis-auth  = ["serviceAccount:${google_service_account.run_api.email}"]
  }
}

# Redis
module "redis" {
  source      = "../../modules/redis"
  project_id  = var.project_id
  name_prefix = local.prefix
  region      = var.region
  network_id  = module.network.network_id

  tier                    = var.redis_tier
  memory_size_gb          = var.redis_memory_gb
  auth_enabled            = var.redis_auth
  transit_encryption_mode = "DISABLED" # ou "SERVER_AUTHENTICATION" si supporté et requis
  labels                  = local.labels

  # Dépendance pour ordre de destruction correct
  service_networking_connection = module.network.service_networking_connection
}

# SQL Server (Cloud SQL privé par défaut, VM fallback possible)
module "sql" {
  source      = "../../modules/sqlserver"
  depends_on  = [module.network, module.vpc_connector]
  project_id  = var.project_id
  name_prefix = local.prefix
  region      = var.region
  labels      = local.labels

  mode              = var.sql_mode
  network_id        = module.network.network_id
  network_self_link = module.network.network_self_link

  # Cloud SQL
  database_version  = var.cloudsql_sqlserver_version
  tier              = var.cloudsql_tier
  disk_size_gb      = var.cloudsql_disk_gb
  disk_type         = var.cloudsql_disk_type
  high_availability = var.cloudsql_ha

  db_name       = var.db_name
  db_user       = var.db_user
  db_password   = var.db_password
  root_password = var.sql_root_password

  # Migration automatique via Cloud Run Job
  run_migration    = var.run_db_migration
  migration_image  = var.db_migration_image
  vpc_connector_id = module.vpc_connector.id

  # Dépendance pour ordre de destruction correct
  service_networking_connection = module.network.service_networking_connection
}

# Cloud Run - Front (sans VPC)
module "cloudrun_front" {
  source      = "../../modules/cloudrun_service"
  project_id  = var.project_id
  name_prefix = local.prefix
  name        = "${local.prefix}-front"
  region      = var.region
  labels      = local.labels

  image                 = var.front_image
  service_account_email = google_service_account.run_front.email
  ingress               = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  default_uri_disabled  = true
  invoker_iam_disabled  = true

  cpu               = "1"
  memory            = "512Mi"
  cpu_idle          = true
  startup_cpu_boost = false

  min_instances = var.front_min_instances
  max_instances = var.front_max_instances
  concurrency   = var.front_concurrency

  env_vars = {
    VITE_API_URL          = "https://${var.api_domain}/api/v1/"
    VITE_GOOGLE_CLIENT_ID = var.google_client_id
  }
}

# Cloud Run - API (avec VPC)
module "cloudrun_api" {
  source      = "../../modules/cloudrun_service"
  project_id  = var.project_id
  name_prefix = local.prefix
  name        = "${local.prefix}-api"
  region      = var.region
  labels      = local.labels

  image                 = var.api_image
  service_account_email = google_service_account.run_api.email

  ingress              = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  default_uri_disabled = true
  invoker_iam_disabled = true

  cpu               = "1"
  memory            = "1024Mi"
  cpu_idle          = true
  startup_cpu_boost = true

  min_instances = var.api_min_instances
  max_instances = var.api_max_instances
  concurrency   = var.api_concurrency

  vpc_connector_id = module.vpc_connector.id
  vpc_egress       = "PRIVATE_RANGES_ONLY"

  env_vars = {
    # Database Connection String
    "ConnectionStrings__Tuuuur" = "Server=${module.sql.private_ip_address},1433;Database=${var.db_name};User Id=${var.db_user};Password=${var.db_password};TrustServerCertificate=True;"

    # Redis Connection String
    "ConnectionStrings__Redis" = var.redis_auth ? "${module.redis.host}:${module.redis.port},password=${var.db_password}" : "${module.redis.host}:${module.redis.port}"

    # JWT Settings
    "JwtSettings__Key" = var.jwt_key

    # Google Authentication
    "Authentification__Google__ClientId" = var.google_client_id

    # SMTP Configuration
    "SmtpEmailConfiguration__FromAddress"  = var.smtp_from_address
    "SmtpEmailConfiguration__FromName"     = var.smtp_from_name
    "SmtpEmailConfiguration__SmtpAddress"  = var.smtp_host
    "SmtpEmailConfiguration__SmtpPort"     = tostring(var.smtp_port)
    "SmtpEmailConfiguration__SmtpLogin"    = var.smtp_user
    "SmtpEmailConfiguration__SmtpPassword" = var.smtp_password
  }

  secret_env_vars = [
    {
      name    = "DB_PASSWORD"
      secret  = module.secrets.secret_ids["db-password"]
      version = "1"
    },
    # optionnel
    {
      name    = "REDIS_AUTH"
      secret  = module.secrets.secret_ids["redis-auth"]
      version = "1"
    }
  ]
}

# Load Balancers (2) — Serverless NEG vers Cloud Run
module "lb_front" {
  source      = "../../modules/lb_serverless"
  project_id  = var.project_id
  name_prefix = "${local.prefix}-front"
  region      = var.region

  cloud_run_service = module.cloudrun_front.service_id
  domains           = [var.front_domain]

  create_dns_records = var.create_dns_records
  dns_zone_name      = var.dns_zone_name
}

module "lb_api" {
  source      = "../../modules/lb_serverless"
  project_id  = var.project_id
  name_prefix = "${local.prefix}-api"
  region      = var.region

  cloud_run_service = module.cloudrun_api.service_id
  domains           = [var.api_domain]

  create_dns_records = var.create_dns_records
  dns_zone_name      = var.dns_zone_name
}

# Bastion (IAP)
module "bastion" {
  source       = "../../modules/bastion"
  project_id   = var.project_id
  name_prefix  = local.prefix
  zone         = var.bastion_zone
  machine_type = var.bastion_machine_type
  labels       = local.labels

  network_id       = module.network.network_id
  subnet_self_link = module.network.subnet_self_links["admin"]
  network_tags     = ["${local.prefix}-bastion"]

  iap_members    = var.bastion_iap_members
  oslogin_admins = var.bastion_oslogin_admins
}

# DNS OVH (optionnel - activé si ovh_domain est défini)
module "ovh_dns_front" {
  count  = var.ovh_domain != null ? 1 : 0
  source = "../../modules/ovh_dns"

  domain    = var.ovh_domain
  subdomain = trimsuffix(var.front_domain, ".${var.ovh_domain}") # Extrait "preprod.tuuuur" de "preprod.tuuuur.florent-dubut.fr"
  target    = module.lb_front.ip_address
}

module "ovh_dns_api" {
  count  = var.ovh_domain != null ? 1 : 0
  source = "../../modules/ovh_dns"

  domain    = var.ovh_domain
  subdomain = trimsuffix(var.api_domain, ".${var.ovh_domain}") # Extrait "api.tuuuur" de "api.tuuuur.florent-dubut.fr"
  target    = module.lb_api.ip_address
}
