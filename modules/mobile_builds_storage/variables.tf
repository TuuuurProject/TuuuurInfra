variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "bucket_name" {
  description = "The name of the GCS bucket for mobile builds"
  type        = string
}

variable "environment" {
  description = "The environment (dev, preprod, prod)"
  type        = string
}
