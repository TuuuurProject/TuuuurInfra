terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.30.0, < 7.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.30.0, < 7.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.35"
    }
    mssql = {
      source  = "betr-io/mssql"
      version = "~> 0.3.0"
    }
  }
}
