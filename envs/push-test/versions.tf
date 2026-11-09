terraform {

  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {

    aws = {

      source  = "hashicorp/aws"
      version = "~> 5.80"

    }

  }

  # Local state contains the Firebase key; do not let this state leave the machine.

}

provider "aws" {

  region = var.aws_region
  default_tags {
    tags = {
      Project   = "fcourt"
      Env       = "push-test"
      ManagedBy = "terraform"
    }
  }

}
