resource "google_compute_firewall" "firewall" {
  name         = var.firewall_name
  network      = var.firewall_network
  description  = var.firewall_description
  priority     = var.firewall_priority

  allow {
    protocol = var.firewall_protocol
    ports    = var.firewall_ports
  }

  source_ranges = length(var.firewall_source_ranges) > 0 ? var.firewall_source_ranges : null
  source_tags   = length(var.firewall_source_tags) > 0 ? var.firewall_source_tags : null
  target_tags   = var.firewall_target_tags
}
