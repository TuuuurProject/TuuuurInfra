# SSH depuis Internet vers le bastion
module "fw_ssh_to_bastion" {
  source                 = "./modules/firewall"
  firewall_name          = "allow-ssh-to-bastion"
  firewall_network       = module.vpc_bastion.object_id
  firewall_description   = "Allow SSH from Internet to Bastion"
  firewall_priority      = 1000
  firewall_protocol      = "tcp"
  firewall_ports         = ["22"]
  firewall_source_ranges = ["0.0.0.0/0"]
  firewall_source_tags   = []
  firewall_target_tags   = ["bastion"]
}

# SSH depuis bastion -> backend & frontend
module "fw_ssh_bastion_to_backend" {
  source                 = "./modules/firewall"
  firewall_name          = "allow-ssh-bastion-to-backend"
  firewall_network       = module.vpc_backend.object_id
  firewall_description   = "Allow SSH from Bastion to Backend"
  firewall_priority      = 1000
  firewall_protocol      = "tcp"
  firewall_ports         = ["22"]
  firewall_source_ranges = ["10.10.1.0/24"]
  firewall_source_tags   = []
  firewall_target_tags   = ["backend"]
}

module "fw_ssh_bastion_to_frontend" {
  source                 = "./modules/firewall"
  firewall_name          = "allow-ssh-bastion-to-frontend"
  firewall_network       = module.vpc_frontend.object_id
  firewall_description   = "Allow SSH from Bastion to Frontend"
  firewall_priority      = 1000
  firewall_protocol      = "tcp"
  firewall_ports         = ["22"]
  firewall_source_ranges = ["10.10.1.0/24"]
  firewall_source_tags   = []
  firewall_target_tags   = ["frontend"]
}

# HTTP depuis Internet vers Frontend
module "fw_http_to_frontend" {
  source                 = "./modules/firewall"
  firewall_name          = "allow-http-to-frontend"
  firewall_network       = module.vpc_frontend.object_id
  firewall_description   = "Allow HTTP from Internet to Frontend"
  firewall_priority      = 1000
  firewall_protocol      = "tcp"
  firewall_ports         = ["80"]
  firewall_source_ranges = ["0.0.0.0/0"]
  firewall_source_tags   = []
  firewall_target_tags   = ["frontend"]
}

# Frontend -> Backend (port 8080)
module "fw_frontend_to_backend" {
  source                 = "./modules/firewall"
  firewall_name          = "allow-frontend-to-backend"
  firewall_network       = module.vpc_backend.object_id
  firewall_description   = "Allow HTTP from Frontend to Backend"
  firewall_priority      = 1000
  firewall_protocol      = "tcp"
  firewall_ports         = ["8080"]
  firewall_source_ranges = ["10.30.1.0/24"]
  firewall_source_tags   = []
  firewall_target_tags   = ["backend"]
}
