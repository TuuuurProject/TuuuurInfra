variable "domain" {
  type        = string
  description = "Nom de domaine OVH (ex: mondomaine.com)"
}

variable "subdomain" {
  type        = string
  description = "Sous-domaine (ex: stage, api-stage)"
}

variable "target" {
  type        = string
  description = "Adresse IP cible"
}

variable "ttl" {
  type    = number
  default = 3600
}
