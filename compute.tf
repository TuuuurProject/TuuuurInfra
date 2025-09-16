module "bastion" {
  source          = "./modules/compute"
  vm_name         = "bastion"
  vm_machine_type = "e2-medium"
  vm_zone         = "${module.global_settings.region}-b"
  vm_tags         = ["bastion"]
  vm_snet         = module.snet_bastion.object_id
}
