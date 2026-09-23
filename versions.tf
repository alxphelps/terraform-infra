terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket = "342989859526.tfstate"
    key    = "terraform-infra/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = var.project_name,
      Github = var.github_url,
      Environment = var.environment
    }
  }
}
