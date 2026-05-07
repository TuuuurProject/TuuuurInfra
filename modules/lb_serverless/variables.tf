variable "project_id" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "cloud_run_service" {
  type        = string
  description = "Nom du service Cloud Run (court), ex: webplat-dev-api"
}

variable "domains" {
  type = list(string)
}

variable "create_dns_records" {
  type    = bool
  default = false
}

variable "dns_zone_name" {
  type    = string
  default = null
}
