terraform {
  backend "gcs" {
    bucket = "tuuuur-terraform-state"
    prefix = "terraform/state/dev"
  }
}
