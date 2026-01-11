provider "google" {
  project = local.project_id
  region  = local.region
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "norel-project-480112-terraform-state"
    prefix = "gke-terraform/terraform.tfstate"
  }
}
