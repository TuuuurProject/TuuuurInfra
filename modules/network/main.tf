resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC dédiée pour ${var.name_prefix}"
}

resource "google_compute_subnetwork" "subnets" {
  for_each                 = var.subnets
  name                     = "${var.name_prefix}-${each.key}-${each.value.region}"
  ip_cidr_range            = each.value.cidr
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = try(each.value.private_google_access, true)
  purpose                  = try(each.value.purpose, null)
  description              = try(each.value.description, null)
}

# Firewall: SSH via IAP uniquement (bastion), pas d'IP publique
resource "google_compute_firewall" "iap_ssh" {
  name      = "${var.name_prefix}-allow-iap-ssh"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"]
  target_tags   = var.bastion_network_tags

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Private Service Access (PSA) — requis pour Cloud SQL Private IP
resource "google_compute_global_address" "psa_range" {
  count         = var.enable_private_service_access ? 1 : 0
  name          = "${var.name_prefix}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_service_access_prefix_length
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "psa_connection" {
  count                   = var.enable_private_service_access ? 1 : 0
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range[0].name]
}
