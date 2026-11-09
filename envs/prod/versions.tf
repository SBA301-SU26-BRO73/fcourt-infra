terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Partial configuration; supply bucket/key via `-backend-config=backend.hcl`.
  backend "s3" {}
}
