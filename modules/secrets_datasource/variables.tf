variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for secret names"
}

variable "secret_names" {
  type        = list(string)
  description = "List of secret names to retrieve (without prefix)"
}
