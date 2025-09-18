variable "secret_name" {
  type        = string
  description = "Nom du secret"
}
variable "secret_value" {
  type        = string
  sensitive   = true
  description = "Valeur du secret"
}
variable "labels" {
  type        = map(string)
  default     = {}
}
