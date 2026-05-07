terraform {
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.35"
    }
  }
}

resource "ovh_domain_zone_record" "record" {
  zone      = var.domain
  subdomain = var.subdomain
  fieldtype = "A"
  ttl       = var.ttl
  target    = var.target
}
