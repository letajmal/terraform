terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.39.1"
    }
  }
}

provider "google" {
  project = var.project_id
  # or set GOOGLE_PROJECT
  region  = var.region
  # or set GOOGLE_REGION
  zone = var.zone
  # or set GOOGLE_ZONE
  impersonate_service_account = var.impersonate_service_account
  # or set GOOGLE_IMPERSONATE_SERVICE_ACCOUNT
}