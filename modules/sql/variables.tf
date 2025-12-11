variable "sql_instance_name" {
  type = string
}

variable "sql_instance_version" {
  type    = string
  default = "SQLSERVER_2022_STANDARD"
}

variable "sql_instance_region" {
  type = string
}

variable "sql_tier" {
  type    = string
  default = "db-custom-2-8192"
}

variable "sql_backup_enabled" {
  type    = bool
  default = true
}

variable "sql_backup_start_time" {
  type    = string
  default = "03:00"
}

variable "sql_deletion_protection" {
  type    = bool
  default = true
}

variable "sql_availability_type" {
  type    = string
  default = "ZONAL"
}

variable "sql_public_ip_enabled" {
  type    = bool
  default = true
}

variable "sql_authorized_networks" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "sql_database_name" {
  type = string
}

variable "sql_user_name" {
  type = string
}
