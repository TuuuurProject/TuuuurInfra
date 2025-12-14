resource "google_vpc_access_connector" "connector" {
  name   = "${var.name_prefix}-vpc"
  region = var.region

  subnet {
    name = var.subnet_name
  }

  machine_type  = var.machine_type
  min_instances = var.min_instances
  max_instances = var.max_instances
}
