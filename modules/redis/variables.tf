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
  type        = string
  default     = "BASIC"
  description = "Service tier: BASIC (standalone) or STANDARD_HA (highly available)"
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
  type        = string
  default     = "DISABLED"
  description = "DISABLED or SERVER_AUTHENTICATION"
}

variable "service_networking_connection" {
  description = "Service Networking Connection dependency for proper destroy order"
  type        = any
  default     = null
}

variable "connect_mode" {
  type        = string
  default     = "PRIVATE_SERVICE_ACCESS"
  description = "DIRECT_PEERING or PRIVATE_SERVICE_ACCESS"
}

variable "location_id" {
  type        = string
  default     = null
  description = "Zone where the instance will be provisioned (optional, service chooses if not provided)"
}

variable "alternative_location_id" {
  type        = string
  default     = null
  description = "Alternative zone for STANDARD_HA tier (must differ from location_id)"
}

variable "display_name" {
  type        = string
  default     = ""
  description = "Display name for the Redis instance"
}

variable "reserved_ip_range" {
  type        = string
  default     = null
  description = "CIDR range for instance (/29 for DIRECT_PEERING, or name for PRIVATE_SERVICE_ACCESS)"
}

variable "persistence_enabled" {
  type        = bool
  default     = false
  description = "Enable RDB persistence"
}

variable "persistence_rdb_snapshot_period" {
  type        = string
  default     = "TWELVE_HOURS"
  description = "RDB snapshot period: ONE_HOUR, SIX_HOURS, TWELVE_HOURS, TWENTY_FOUR_HOURS"
}

variable "replica_count" {
  type        = number
  default     = null
  description = "Number of replica nodes for STANDARD_HA with read replicas (1-5)"
}

variable "read_replicas_mode" {
  type        = string
  default     = "READ_REPLICAS_DISABLED"
  description = "READ_REPLICAS_DISABLED or READ_REPLICAS_ENABLED (STANDARD_HA only)"
}
