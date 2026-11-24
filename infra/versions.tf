terraform {
  # use_lockfile = нативный S3-локинг без DynamoDB, требует >= 1.11
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "wireguard"
      ManagedBy = "terraform"
    }
  }
}
