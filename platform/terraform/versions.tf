terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "cyb3r-kub3n3t3s"
      Version   = "v2-github-actions"
      ManagedBy = "terraform"
    }
  }
}