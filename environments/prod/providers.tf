provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Provider OVH - uses environment variables:
# - OVH_APPLICATION_KEY
# - OVH_APPLICATION_SECRET
# - OVH_CONSUMER_KEY
provider "ovh" {
  endpoint = "ovh-eu"
}

data "google_project" "this" {
  project_id = var.project_id
}
