terraform {

  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {

    aws = {

      source  = "hashicorp/aws"
      version = "~> 5.80"

    }

  }
  backend "s3" {

  }

}

provider "aws" {

  region = var.aws_region
  default_tags {
    tags = {
      Project   = "fcourt"
      Env       = "prod"
      ManagedBy = "terraform"
    }
  }

}
