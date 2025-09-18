module "vpc_bastion" {
  source = "./modules/vpc"
  vpc_name = "vpc-bastion"
}

module "vpc_backend" {
  source = "./modules/vpc"
  vpc_name = "vpc-backend"
}

module "vpc_frontend" {
  source = "./modules/vpc"
  vpc_name = "vpc-frontend"
}
