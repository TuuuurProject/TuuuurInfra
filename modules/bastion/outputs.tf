output "name" { value = google_compute_instance.bastion.name }
output "zone" { value = google_compute_instance.bastion.zone }
output "internal_ip" { value = google_compute_instance.bastion.network_interface[0].network_ip }
