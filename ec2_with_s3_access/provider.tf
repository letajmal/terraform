terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.59.0"
    }
  }
}

provider "aws" {
  # Configuration options
  default_tags {
    tags = {
      Name = var.resource_prefix
    }
  }
  shared_config_files      = ["C:\\Users\\LENOVO\\.aws\\config"]
  shared_credentials_files = ["C:\\Users\\LENOVO\\.aws\\credentials"]
  profile                  = "terraform"
}
