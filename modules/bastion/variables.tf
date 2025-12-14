variable "project_id" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "zone" {
  type = string
}

variable "machine_type" {
  type    = string
  default = "e2-micro"
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "network_id" {
  type = string
}

variable "subnet_self_link" {
  type = string
}

variable "network_tags" {
  type    = list(string)
  default = []
}

variable "iap_members" {
  type        = list(string)
  default     = []
  description = "IAM members autorisés à utiliser IAP TCP forwarding."
}

variable "oslogin_admins" {
  type        = list(string)
  default     = []
  description = "IAM members avec rôles OS Login admin."
}

variable "image" {
  type    = string
  default = "projects/debian-cloud/global/images/family/debian-12"
}
