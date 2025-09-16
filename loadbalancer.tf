module "lb" {
  source        = "./modules/load_balancer"
  name          = "tuuur"
  frontend_group= module.frontend_mig.instance_group
  backend_group = module.backend_mig.instance_group
}
