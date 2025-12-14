variable "project_id" {
  type = string
}

variable "services" {
  type = list(string)
  default = [
    "compute.googleapis.com",
    "run.googleapis.com",
    "vpcaccess.googleapis.com",
    "secretmanager.googleapis.com",
    "redis.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "iap.googleapis.com",
    "dns.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ]
}
