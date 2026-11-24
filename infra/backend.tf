terraform {
  backend "s3" {
    bucket       = "k8s-lab-tfstate-347288885877"
    key          = "wireguard/terraform.tfstate"
    region       = "eu-central-1"
    profile      = "k8s-lab-admin"
    encrypt      = true
    use_lockfile = true
  }
}
