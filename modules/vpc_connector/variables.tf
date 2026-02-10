variable "project_id" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "network_id" {
  type        = string
  default     = null
  description = "Not used - kept for backwards compatibility"
}

variable "subnet_name" {
  type = string
}

variable "machine_type" {
  type    = string
  default = "e2-micro"
}

variable "min_instances" {
  type    = number
  default = 2
}

variable "max_instances" {
  type    = number
  default = 3
}
