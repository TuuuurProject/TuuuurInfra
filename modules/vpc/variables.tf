variable "vpc_name" {
  type        = string
  description = "Nom du VPC"
}
variable "vpc_auto_create_subnetworks" {
  type        = bool
  description = "Créer automatiquement des sous-réseaux"
  default     = false
}
