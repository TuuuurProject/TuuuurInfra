variable "project_id" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "subnets" {
  type = map(object({
    cidr                  = string
    region                = string
    private_google_access = optional(bool, true)
    purpose               = optional(string, null)
    description           = optional(string, null)
  }))
}

variable "enable_private_service_access" {
  type    = bool
  default = true
}

variable "private_service_access_prefix_length" {
  type        = number
  default     = 16
  description = "Taille du range réservé PSA (recommandé /16)."
}
