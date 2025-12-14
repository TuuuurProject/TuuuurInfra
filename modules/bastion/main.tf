resource "google_service_account" "bastion" {
  account_id   = "${var.name_prefix}-bastion"
  display_name = "${var.name_prefix} Bastion"
}

resource "google_compute_instance" "bastion" {
  name         = "${var.name_prefix}-bastion"
  zone         = var.zone
  machine_type = var.machine_type
  tags         = var.network_tags

  boot_disk {
    initialize_params {
      image = var.image
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnet_self_link
    # pas d'access_config => pas d'IP publique
  }

  service_account {
    email  = google_service_account.bastion.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  labels = var.labels
}

# IAP TCP forwarding access
resource "google_project_iam_member" "iap_access" {
  for_each = toset(var.iap_members)
  project  = var.project_id
  role     = "roles/iap.tunnelResourceAccessor"
  member   = each.value
}

# OS Login admin (optionnel)
resource "google_project_iam_member" "oslogin_admin" {
  for_each = toset(var.oslogin_admins)
  project  = var.project_id
  role     = "roles/compute.osAdminLogin"
  member   = each.value
}
