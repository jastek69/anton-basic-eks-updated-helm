/*
terraform {
  backend "s3" {
    bucket       = "taaops-terraform-state-oregon"
    key          = "global/kubernetes-terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
*/