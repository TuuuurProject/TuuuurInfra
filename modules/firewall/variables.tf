variable "firewall_name" {
  type = string
}

variable "firewall_network" {
  type = string
}

variable "firewall_description" {
  type    = string
  default = ""
}

variable "firewall_priority" {
  type    = number
  default = 1000
}

variable "firewall_protocol" {
  type = string
}

variable "firewall_ports" {
  type = list(string)
}

variable "firewall_source_ranges" {
  type    = list(string)
  default = []
}

variable "firewall_source_tags" {
  type    = list(string)
  default = []
}

variable "firewall_target_tags" {
  type    = list(string)
  default = []
}
