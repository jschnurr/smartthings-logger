terraform {
  required_version = "~>1.2.4"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.27.0"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = var.region
}

