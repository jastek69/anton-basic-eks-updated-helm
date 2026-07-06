variable "enable_kubeconfig" {
  default     = true
  description = "Set to false to skip local kubeconfig update"
}

variable "region" {
  default     = "us-west-2"
  description = "AWS Region"
}

# core VPC paramters 
variable "vpc_cidr" {
  default = "10.100.0.0/16"
}

variable "subnet_cidr_blocks" {
  description = "CIDR blocks for all subnets by name"
  type = object({
    eks_private_zone1 = string
    eks_private_zone2 = string
    eks_public_zone1  = string
    eks_public_zone2  = string
  })
  default = {
    eks_private_zone1 = "10.100.0.0/19"
    eks_private_zone2 = "10.100.32.0/19"
    eks_public_zone1  = "10.100.64.0/19"
    eks_public_zone2  = "10.100.96.0/19"
  }
}


locals {
  zone1 = "${var.region}a"
  zone2 = "${var.region}b"
}

variable "cluster_name" {
  default     = "demo"
  type        = string
  description = "AWS EKS CLuster Name"
  nullable    = false
}

# EKS OIDC ROOT CA Thumbprint - valid until 2037
variable "eks_oidc_root_ca_thumbprint" {
  type        = string
  description = "Thumbprint of Root CA for EKS OIDC, Valid until 2037"
  default     = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
}

# EC2 Node settings for EKS Node Group
variable "ec2_instance_types" {
  type        = list(string)
  description = "List of EC2 instance types for EKS Node Group"
  default     = ["t3.large"]
}

variable "ec2_desired_size" {
  type        = number
  description = "Desired size of EKS Node Group"
  default     = 2
}

variable "ec2_max_size" {
  type        = number
  description = "Max size of EKS Node Group"
  default     = 5
}

variable "ec2_min_size" {
  type        = number
  description = "Min size of EKS Node Group"
  default     = 0
}