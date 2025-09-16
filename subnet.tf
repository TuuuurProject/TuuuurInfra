module "snet_bastion" {
  source              = "./modules/subnet"
  subnet_name         = "snet-bastion"
  subnet_ip_cidr_range= "10.10.1.0/24"
  subnet_network      = module.vpc_bastion.object_id
  subnet_region       = module.global_settings.region
}

module "snet_backend" {
  source              = "./modules/subnet"
  subnet_name         = "snet-backend"
  subnet_ip_cidr_range= "10.20.1.0/24"
  subnet_network      = module.vpc_backend.object_id
  subnet_region       = module.global_settings.region
}

module "snet_frontend" {
  source              = "./modules/subnet"
  subnet_name         = "snet-frontend"
  subnet_ip_cidr_range= "10.30.1.0/24"
  subnet_network      = module.vpc_frontend.object_id
  subnet_region       = module.global_settings.region
}
