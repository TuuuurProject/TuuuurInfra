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

variable "network_id" {
  type = string
}

variable "tier" {
  type    = string
  default = "BASIC"
}

variable "memory_size_gb" {
  type    = number
  default = 1
}

variable "redis_version" {
  type    = string
  default = "REDIS_7_0"
}

variable "auth_enabled" {
  type    = bool
  default = false
}

variable "transit_encryption_mode" {
  type    = string
  default = "DISABLED" # ou SERVER_AUTHENTICATION
}

variable "service_networking_connection" {
  description = "Service Networking Connection dependency for proper destroy order"
  type        = any
  default     = null
}
