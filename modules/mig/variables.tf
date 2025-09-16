variable "name" { type = string }
variable "machine_type" { type = string default = "e2-medium" }
variable "tags" { type = list(string) default = [] }
variable "image" { type = string default = "ubuntu-os-cloud/ubuntu-2004-lts" }
variable "subnet" { type = string }
variable "assign_public_ip" { type = bool default = false }
variable "metadata" { type = map(string) default = {} }
variable "service_account_email" { type = string }
variable "zone" { type = string }
variable "port" { type = number }
variable "port_name" { type = string default = "http" }
variable "min_size" { type = number default = 1 }
variable "max_size" { type = number default = 5 }
