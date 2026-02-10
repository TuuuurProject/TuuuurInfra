variable "project_id" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "image" {
  type = string
}

variable "service_account_email" {
  type = string
}

variable "ingress" {
  type    = string
  default = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
}

variable "default_uri_disabled" {
  type    = bool
  default = true
}

variable "invoker_iam_disabled" {
  type        = bool
  default     = true
  description = "True => pas de contrôle IAM d'invocation (équivalent allow unauth)."
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "cpu_idle" {
  type    = bool
  default = true
}

variable "startup_cpu_boost" {
  type    = bool
  default = false
}

variable "timeout_seconds" {
  type    = number
  default = 60
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 50
}

variable "concurrency" {
  type    = number
  default = 80
}

variable "env_vars" {
  type    = map(string)
  default = {}
}

variable "secret_env_vars" {
  type = list(object({
    name    = string
    secret  = string
    version = optional(string, "latest")
  }))
  default = []
}

variable "vpc_connector_id" {
  type    = string
  default = null
}

variable "vpc_egress" {
  type    = string
  default = "PRIVATE_RANGES_ONLY"
}
