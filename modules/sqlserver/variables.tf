variable "project_id" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "mode" {
  type        = string
  default     = "cloudsql"
  description = "cloudsql | vm"
}

variable "network_id" {
  type        = string
  description = "VPC network id (utilisé pour firewall VM)."
}

variable "network_self_link" {
  type        = string
  description = "VPC self_link (nécessaire pour Cloud SQL private_network)."
}

# Cloud SQL (SQL Server)
variable "database_version" {
  type    = string
  default = "SQLSERVER_2022_STANDARD"
}

variable "tier" {
  type    = string
  default = "db-custom-1-3840"
}

variable "disk_size_gb" {
  type    = number
  default = 50
}

variable "disk_type" {
  type    = string
  default = "PD_SSD"
}

variable "high_availability" {
  type    = bool
  default = false
} # REGIONAL si true

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
}

variable "root_password" {
  type        = string
  sensitive   = true
  description = "Root password for SQL Server instance"
}

variable "run_migration" {
  type        = bool
  default     = true
  description = "Si true, exécute automatiquement la migration SQL via Cloud Run Job après la création de la base de données."
}

variable "migration_image" {
  type        = string
  default     = ""
  description = "Image Docker contenant sqlpackage et le DACPAC pour migrer la base de données. Ex: europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod"
}

variable "vpc_connector_id" {
  type        = string
  default     = null
  description = "ID du VPC Connector pour permettre au Cloud Run Job d'accéder à Cloud SQL en privé."
}

variable "service_networking_connection" {
  description = "Service Networking Connection dependency for proper destroy order"
  type        = any
  default     = null
}
