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

# VM fallback (Compute Engine SQL Server)
variable "vm_zone" {
  type    = string
  default = "europe-west9-b"
}

variable "vm_machine_type" {
  type    = string
  default = "n2-standard-2"
}

variable "vm_image" {
  type    = string
  default = "windows-sql-cloud/sql-std-2019-win-2022"
}

variable "vm_boot_disk_gb" {
  type    = number
  default = 50
}

variable "vm_subnet_self_link" {
  type    = string
  default = null
}

variable "allowed_source_ranges" {
  type        = list(string)
  default     = []
  description = "Sources autorisées vers la VM SQL Server (TCP 1433) : ex CIDR connector + admin subnet."
}
