resource "google_compute_network_peering" "bastion_to_backend" {
  name         = "bastion-to-backend"
  network      = module.vpc_bastion.network_name
  peer_network = module.vpc_backend.network_name
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "backend_to_bastion" {
  name         = "backend-to-bastion"
  network      = module.vpc_backend.network_name
  peer_network = module.vpc_bastion.network_name
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "frontend_to_backend" {
  name         = "frontend-to-backend"
  network      = module.vpc_frontend.network_name
  peer_network = module.vpc_backend.network_name
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "backend_to_frontend" {
  name         = "backend-to-frontend"
  network      = module.vpc_backend.network_name
  peer_network = module.vpc_frontend.network_name
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "bastion_to_frontend" {
  name         = "bastion-to-frontend"
  network      = module.vpc_bastion.network_name
  peer_network = module.vpc_frontend.network_name
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "frontend_to_bastion" {
  name         = "frontend-to-bastion"
  network      = module.vpc_frontend.network_name
  peer_network = module.vpc_bastion.network_name
  export_custom_routes = true
  import_custom_routes = true
}
