variable "project_id" { type = string }
variable "region"     { type = string default = "europe-west1" }
variable "env"        { type = string } # dev | stage | prod
variable "app_name"   { type = string default = "webplat" }

variable "front_image" { type = string } # ex: europe-west1-docker.pkg.dev/PROJ/repo/front:tag
variable "api_image"   { type = string } # ex: europe-west1-docker.pkg.dev/PROJ/repo/api:tag

variable "front_domain" { type = string } # ex: app.example.com
variable "api_domain"   { type = string } # ex: api.example.com

variable "create_dns_records" { type = bool default = false }
variable "dns_zone_name"      { type = string default = null } # Cloud DNS managed zone name in this project

# Réseau (CIDRs à adapter si besoin)
variable "app_subnet_cidr"   { type = string default = "10.10.0.0/24" }
variable "admin_subnet_cidr" { type = string default = "10.20.0.0/24" }

# Serverless VPC Access connector CIDR (doit être /28, distinct des subnets)
variable "connector_cidr" { type = string default = "10.30.0.0/28" }

# Redis
variable "redis_memory_gb"  { type = number default = 1 }
variable "redis_tier"       { type = string default = "BASIC" } # BASIC (moins cher) ou STANDARD_HA
variable "redis_auth"       { type = bool default = false }     # true => Redis AUTH (recommandé si possible)

# SQL Server
variable "sql_mode" { type = string default = "cloudsql" } # cloudsql | vm

# Cloud SQL for SQL Server
variable "cloudsql_sqlserver_version" {
  type        = string
  default     = "SQLSERVER_2022_STANDARD"
  description = "Ex: SQLSERVER_2019_STANDARD, SQLSERVER_2022_STANDARD, etc."
}
variable "cloudsql_tier"       { type = string default = "db-custom-1-3840" }
variable "cloudsql_disk_gb"    { type = number default = 50 }
variable "cloudsql_disk_type"  { type = string default = "PD_SSD" }
variable "cloudsql_ha"         { type = bool default = false } # false => ZONAL (moins cher), true => REGIONAL (plus cher)

variable "db_name" { type = string default = "appdb" }
variable "db_user" { type = string default = "appuser" }
variable "db_password" {
  type      = string
  sensitive = true
}

# SQL Server VM fallback
variable "sql_vm_zone"         { type = string default = "europe-west1-b" }
variable "sql_vm_machine_type" { type = string default = "n2-standard-2" }
variable "sql_vm_boot_disk_gb" { type = number default = 50 }
variable "sql_vm_image" {
  type        = string
  default     = "windows-sql-cloud/sql-std-2019-win-2022"
  description = "Voir doc Compute Engine SQL Server; ex: windows-sql-cloud/sql-std-2019-win-2022"
}

# Cloud Run tuning
variable "front_min_instances" { type = number default = 0 }
variable "front_max_instances" { type = number default = 50 }
variable "front_concurrency"   { type = number default = 80 }

variable "api_min_instances" { type = number default = 0 }
variable "api_max_instances" { type = number default = 50 }
variable "api_concurrency"   { type = number default = 40 }

# Labels communs
variable "labels" {
  type    = map(string)
  default = {}
}

# Bastion / IAP
variable "bastion_zone"         { type = string default = "europe-west1-b" }
variable "bastion_machine_type" { type = string default = "e2-micro" }
variable "bastion_iap_members" {
  type        = list(string)
  default     = []
  description = "IAM members autorisés IAP TCP (ex: user:alice@example.com, group:ops@example.com)"
}
variable "bastion_oslogin_admins" {
  type        = list(string)
  default     = []
  description = "IAM members avec OS Admin Login (optionnel) : user:/group:"
}
