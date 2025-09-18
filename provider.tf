terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }
  }
}

module "global_settings" {
  source = "./modules/global_constants"
}

provider "google" {
  project = module.global_settings.project_id
  region  = module.global_settings.region
}
