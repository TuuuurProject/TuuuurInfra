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

variable "secrets" {
  type = map(object({
    labels = optional(map(string), {})
  }))
}

variable "create_versions" {
  type    = bool
  default = false
}

variable "secret_values" {
  type      = map(string)
  default   = {}
  sensitive = true
}

variable "accessors" {
  type        = map(list(string))
  default     = {}
  description = "Map secret_name => list of IAM members (ex: serviceAccount:xxx)."
}
