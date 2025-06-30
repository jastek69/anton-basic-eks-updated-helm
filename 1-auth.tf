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
    bucket  = "kiyakubernetes" # Name of the S3 bucket
    key     = "062925.tfstate"           # The name of the state file in the bucket
    region  = "us-east-1"                # Use a variable for the region
    encrypt = true                       # Enable server-side encryption (optional but recommended)
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}
