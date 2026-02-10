variable "domain" {
  type        = string
  description = "Nom de domaine OVH (ex: mondomaine.com)"
}

variable "subdomain" {
  type        = string
  description = "Sous-domaine (ex: preprod, api-preprod)"
}

variable "target" {
  type        = string
  description = "Adresse IP cible"
}

variable "ttl" {
  type    = number
  default = 3600
}
