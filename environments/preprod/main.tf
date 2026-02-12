locals {
  prefix = "${var.app_name}-${var.env}"
  labels = merge(var.labels, {
    app = var.app_name
    env = var.env
  })
  
  # Construire les URLs des images Docker à partir des SHA Git stockés dans Secret Manager
  docker_registry = "europe-west9-docker.pkg.dev/tuuuur/tuuuur"
  front_image     = "${local.docker_registry}/web:${data.google_secret_manager_secret_version.web_git_sha.secret_data}"
  api_image       = "${local.docker_registry}/api:${data.google_secret_manager_secret_version.api_git_sha.secret_data}"
  db_migration_image = "${local.docker_registry}/database:${data.google_secret_manager_secret_version.database_git_sha.secret_data}"
}

# Lire les SHA Git depuis Secret Manager (noms spécifiques)
data "google_secret_manager_secret_version" "web_git_sha" {
  secret  = "tuuuur-web-${var.env}-git-sha"
  project = var.project_id
}

data "google_secret_manager_secret_version" "api_git_sha" {
  secret  = "tuuuur-api-${var.env}-git-sha"
  project = var.project_id
}

data "google_secret_manager_secret_version" "database_git_sha" {
  secret  = "tuuuur-database-${var.env}-git-sha"
  project = var.project_id
}

# Read secrets from GCP Secret Manager (created by push-secrets-to-gcp.sh script)
module "gcp_secrets" {
  source      = "../../modules/secrets_datasource"
  project_id  = var.project_id
  name_prefix = local.prefix

  secret_names = [
    "region",
    "db-password",
    "sql-root-password",
    "jwt-key",
    "google-client-id",
    "smtp-from-address",
    "smtp-from-name",
    "smtp-host",
    "smtp-user",
    "smtp-password",
    "front-domain",
    "api-domain",
    "ovh-domain",
    "redis-auth"
  ]
}

module "project_services" {
  source     = "../../modules/project_services"
  project_id = var.project_id
}

resource "google_service_account" "run_front" {
  account_id   = "${local.prefix}-front"
  display_name = "${local.prefix} Cloud Run Front"
}

resource "google_service_account" "run_api" {
  account_id   = "${local.prefix}-api"
  display_name = "${local.prefix} Cloud Run API"
}

resource "google_secret_manager_secret_iam_member" "api_db_password_access" {
  project   = var.project_id
  secret_id = "${local.prefix}-db-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_redis_auth_access" {
  project   = var.project_id
  secret_id = "${local.prefix}-redis-auth"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_api.email}"
}

module "network" {
  source      = "../../modules/network"
  project_id  = var.project_id
  name_prefix = local.prefix
  labels      = local.labels

  subnets = {
    connector = {
      cidr                  = var.connector_cidr
      region                = module.gcp_secrets.config["region"]
      private_google_access = true
    }
  }

  enable_private_service_access        = true
  private_service_access_prefix_length = 16
}

module "vpc_connector" {
  source      = "../../modules/vpc_connector"
  project_id  = var.project_id
  name_prefix = local.prefix
  region      = module.gcp_secrets.config["region"]

  subnet_name = module.network.subnet_names["connector"]

  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
}

module "redis" {
  source      = "../../modules/redis"
  project_id  = var.project_id
  name_prefix = local.prefix
  region      = module.gcp_secrets.config["region"]
  network_id  = module.network.network_id

  tier                    = var.redis_tier
  memory_size_gb          = var.redis_memory_gb
  auth_enabled            = var.redis_auth
  transit_encryption_mode = "DISABLED"
  labels                  = local.labels

  service_networking_connection = module.network.service_networking_connection

  depends_on = [module.project_services]
}

module "sql" {
  source      = "../../modules/sqlserver"
  depends_on  = [module.network, module.vpc_connector]
  project_id  = var.project_id
  name_prefix = local.prefix
  region      = module.gcp_secrets.config["region"]
  labels      = local.labels

  mode              = var.sql_mode
  network_id        = module.network.network_id
  network_self_link = module.network.network_self_link

  database_version  = var.cloudsql_sqlserver_version
  tier              = var.cloudsql_tier
  disk_size_gb      = var.cloudsql_disk_gb
  disk_type         = var.cloudsql_disk_type
  high_availability = var.cloudsql_ha

  db_name       = var.db_name
  db_user       = var.db_user
  db_password   = module.gcp_secrets.secrets["db-password"]
  root_password = module.gcp_secrets.secrets["sql-root-password"]

  run_migration    = var.run_db_migration
  migration_image  = local.db_migration_image
  vpc_connector_id = module.vpc_connector.id

  service_networking_connection = module.network.service_networking_connection
}

module "cloudrun_front" {
  source      = "../../modules/cloudrun_service"
  project_id  = var.project_id
  name_prefix = local.prefix
  name        = "${local.prefix}-front"
  region      = module.gcp_secrets.config["region"]
  labels      = local.labels

  image                 = local.front_image
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
}

resource "google_cloud_run_v2_service_iam_member" "front_invoker" {
  depends_on = [module.cloudrun_front]
  project    = var.project_id
  location   = module.gcp_secrets.config["region"]
  name       = module.cloudrun_front.service_id
  role       = "roles/run.invoker"
  member     = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "api_invoker" {
  depends_on = [module.cloudrun_api]
  project    = var.project_id
  location   = module.gcp_secrets.config["region"]
  name       = module.cloudrun_api.service_id
  role       = "roles/run.invoker"
  member     = "allUsers"
}

module "cloudrun_api" {
  source      = "../../modules/cloudrun_service"
  depends_on  = [module.sql, module.redis]
  project_id  = var.project_id
  name_prefix = local.prefix
  name        = "${local.prefix}-api"
  region      = module.gcp_secrets.config["region"]
  labels      = local.labels

  image                 = local.api_image
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
    "ConnectionStrings__Tuuuur" = "Server=${module.sql.private_ip_address},1433;Database=${var.db_name};User Id=${var.db_user};Password=${module.gcp_secrets.secrets["db-password"]};TrustServerCertificate=True;"

    # Redis connection - auth is passed via REDIS_AUTH secret_env_var, not here
    "ConnectionStrings__Redis" = "${module.redis.host}:${module.redis.port}"

    "JwtSettings__Key" = module.gcp_secrets.secrets["jwt-key"]

    "Authentification__Google__ClientId" = module.gcp_secrets.secrets["google-client-id"]

    "SmtpEmailConfiguration__FromAddress"  = module.gcp_secrets.secrets["smtp-from-address"]
    "SmtpEmailConfiguration__FromName"     = module.gcp_secrets.secrets["smtp-from-name"]
    "SmtpEmailConfiguration__SmtpAddress"  = module.gcp_secrets.secrets["smtp-host"]
    "SmtpEmailConfiguration__SmtpPort"     = tostring(var.smtp_port)
    "SmtpEmailConfiguration__SmtpLogin"    = module.gcp_secrets.secrets["smtp-user"]
    "SmtpEmailConfiguration__SmtpPassword" = module.gcp_secrets.secrets["smtp-password"]
  }

  secret_env_vars = [
    {
      name    = "DB_PASSWORD"
      secret  = "${local.prefix}-db-password"
      version = "latest"
    },
    {
      name    = "REDIS_AUTH"
      secret  = "${local.prefix}-redis-auth"
      version = "latest"
    }
  ]
}

module "lb_front" {
  source      = "../../modules/lb_serverless"
  project_id  = var.project_id
  name_prefix = "${local.prefix}-front"
  region      = module.gcp_secrets.config["region"]

  cloud_run_service = module.cloudrun_front.service_id
  domains           = [module.gcp_secrets.config["front-domain"]]

  create_dns_records = var.create_dns_records
  dns_zone_name      = var.dns_zone_name
}

module "lb_api" {
  source      = "../../modules/lb_serverless"
  project_id  = var.project_id
  name_prefix = "${local.prefix}-api"
  region      = module.gcp_secrets.config["region"]

  cloud_run_service = module.cloudrun_api.service_id
  domains           = [module.gcp_secrets.config["api-domain"], "tuuuur.api.florent-dubut.fr"]

  create_dns_records = var.create_dns_records
  dns_zone_name      = var.dns_zone_name
}

module "ovh_dns_front" {
  count      = try(module.gcp_secrets.config["ovh-domain"], null) != null && module.gcp_secrets.config["ovh-domain"] != "" ? 1 : 0
  source     = "../../modules/ovh_dns"
  depends_on = [module.lb_front]

  domain    = module.gcp_secrets.config["ovh-domain"]
  subdomain = trimsuffix(module.gcp_secrets.config["front-domain"], ".${module.gcp_secrets.config["ovh-domain"]}")
  target    = module.lb_front.ip_address
}

module "ovh_dns_api" {
  count      = try(module.gcp_secrets.config["ovh-domain"], null) != null && module.gcp_secrets.config["ovh-domain"] != "" ? 1 : 0
  source     = "../../modules/ovh_dns"
  depends_on = [module.lb_api]

  domain    = module.gcp_secrets.config["ovh-domain"]
  subdomain = trimsuffix(module.gcp_secrets.config["api-domain"], ".${module.gcp_secrets.config["ovh-domain"]}")
  target    = module.lb_api.ip_address
}

module "ovh_dns_api_prod_like" {
  count      = try(module.gcp_secrets.config["ovh-domain"], null) != null && module.gcp_secrets.config["ovh-domain"] != "" ? 1 : 0
  source     = "../../modules/ovh_dns"
  depends_on = [module.lb_api]

  domain    = module.gcp_secrets.config["ovh-domain"]
  subdomain = "tuuuur.api"
  target    = module.lb_api.ip_address
}
