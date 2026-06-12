variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west9"
}

variable "env" {
  type = string
}

variable "app_name" {
  type    = string
  default = "webplat"
}

variable "front_image" {
  type    = string
  default = ""
}

variable "api_image" {
  type    = string
  default = ""
}

variable "front_domain" {
  type    = string
  default = ""
}

variable "api_domain" {
  type    = string
  default = ""
}

variable "create_dns_records" {
  type    = bool
  default = false
}

variable "dns_zone_name" {
  type    = string
  default = null
}

variable "ovh_domain" {
  type        = string
  description = "Nom de domaine OVH (ex: mondomaine.com)"
  default     = null
}

variable "connector_cidr" {
  type    = string
  default = "10.30.0.0/28"
}

variable "redis_memory_gb" {
  type    = number
  default = 1
}

variable "redis_tier" {
  type    = string
  default = "BASIC"
}

variable "redis_auth" {
  type    = bool
  default = false
}

variable "sql_mode" {
  type    = string
  default = "cloudsql"
}

variable "cloudsql_sqlserver_version" {
  type    = string
  default = "SQLSERVER_2025_EXPRESS"
}

variable "cloudsql_tier" {
  type    = string
  default = "db-custom-1-3840"
}

variable "cloudsql_disk_gb" {
  type    = number
  default = 50
}

variable "cloudsql_disk_type" {
  type    = string
  default = "PD_SSD"
}

variable "cloudsql_ha" {
  type    = bool
  default = false
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_user" {
  type    = string
  default = "appuser"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "sql_root_password" {
  type        = string
  sensitive   = true
  description = "SQL Server root/admin password"
  default     = ""
}

variable "sql_vm_zone" {
  type    = string
  default = "europe-west9"
}

variable "sql_vm_machine_type" {
  type    = string
  default = "n2-standard-2"
}

variable "sql_vm_boot_disk_gb" {
  type    = number
  default = 50
}

variable "sql_vm_image" {
  type        = string
  default     = "windows-sql-cloud/sql-std-2025-win-2022"
  description = "Voir doc Compute Engine SQL Server; ex: windows-sql-cloud/sql-std-2025-win-2022"
}

variable "front_min_instances" {
  type    = number
  default = 0
}

variable "front_max_instances" {
  type    = number
  default = 50
}

variable "front_concurrency" {
  type    = number
  default = 80
}

variable "api_min_instances" {
  type    = number
  default = 0
}

variable "api_max_instances" {
  type    = number
  default = 50
}

variable "api_concurrency" {
  type    = number
  default = 40
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "jwt_key" {
  type        = string
  sensitive   = true
  description = "JWT signing key"
  default     = ""
}

variable "google_client_id" {
  type        = string
  description = "Google OAuth Client ID"
  default     = ""
}

variable "smtp_from_address" {
  type        = string
  description = "SMTP From email address"
  default     = ""
}

variable "smtp_from_name" {
  type        = string
  description = "SMTP From display name"
  default     = ""
}

variable "smtp_host" {
  type        = string
  description = "SMTP server address"
  default     = ""
}

variable "smtp_port" {
  type        = number
  default     = 587
  description = "SMTP server port"
}

variable "smtp_user" {
  type        = string
  description = "SMTP username"
  default     = ""
}

variable "smtp_password" {
  type        = string
  sensitive   = true
  description = "SMTP password"
  default     = ""
}

variable "run_db_migration" {
  type        = bool
  default     = true
  description = "Si true, exécute automatiquement la migration de la base de données via Cloud Run Job après création"
}

variable "db_migration_image" {
  type        = string
  default     = ""
  description = "Image Docker pour la migration SQL (DACPAC). Ex: europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod"
}
