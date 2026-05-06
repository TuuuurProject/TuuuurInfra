variable "project_id" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "accessors" {
  type        = map(list(string))
  default     = {}
  description = "Map secret_name => list of IAM members (ex: serviceAccount:xxx) for existing secrets."
}
