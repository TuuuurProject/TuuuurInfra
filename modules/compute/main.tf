resource "google_compute_instance" "instance" {
  name         = var.vm_name
  machine_type = var.vm_machine_type
  zone         = var.vm_zone
  tags         = var.vm_tags

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    subnetwork = var.vm_snet
    access_config {}
  }

  metadata = {
    ssh-keys = "user:${file("~/.ssh/id_ed25519.pub")}"
  }
}
