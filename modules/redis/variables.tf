variable "name" {
  type        = string
  description = "Redis instance name"
}

variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "size_gb" {
  type        = number
  default     = 5
  description = "Redis memory size in GB"
}

variable "tier" {
  type        = string
  default     = "BASIC"
  description = "Redis tier (BASIC or STANDARD)"
}

variable "redis_version" {
  type        = string
  default     = "7.2"
  description = "Redis version"
}
