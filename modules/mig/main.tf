resource "google_compute_instance_template" "tpl" {
  name        = "${var.name}-tpl"
  machine_type = var.machine_type
  tags         = var.tags

  disk {
    source_image = var.image
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork   = var.subnet
    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }

  metadata = var.metadata

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance_group_manager" "mig" {
  name               = "${var.name}-mig"
  base_instance_name = var.name
  zone               = var.zone
  target_size        = var.min_size

  version {
    instance_template = google_compute_instance_template.tpl.self_link
  }

  named_port {
    name = var.port_name
    port = var.port
  }
}

resource "google_compute_autoscaler" "as" {
  name   = "${var.name}-as"
  zone   = var.zone
  target = google_compute_instance_group_manager.mig.id

  autoscaling_policy {
    min_replicas    = var.min_size
    max_replicas    = var.max_size
    cooldown_period = 60
    cpu_utilization { target = 0.6 }
  }
}

output "instance_group" {
  value = google_compute_instance_group_manager.mig.instance_group
}
