terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Use latest version if possible
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11" # use latest version if possible
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }


  backend "s3" {
    bucket       = "taaops-terraform-state-oregon"
    key          = "global/kubernetes-terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }

}

provider "aws" {
  region  = "us-west-2" # Use a variable for the region
  profile = "default"
}
