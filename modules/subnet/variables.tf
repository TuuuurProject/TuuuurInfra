variable "subnet_name" {
  type        = string
  description = "Nom du sous-réseau"
}
variable "subnet_ip_cidr_range" {
  type        = string
  description = "CIDR du sous-réseau"
}
variable "subnet_network" {
  type        = string
  description = "ID du VPC"
}
variable "subnet_region" {
  type        = string
  description = "Région du sous-réseau"
}
