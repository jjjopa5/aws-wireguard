terraform {
  # use_lockfile = нативный S3-локинг без DynamoDB, требует >= 1.11
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "k8s-lab-tfstate-347288885877"
    key          = "wireguard/terraform.tfstate"
    region       = "eu-central-1"
    profile      = "k8s-lab-admin"
    encrypt      = true
    use_lockfile = true
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
