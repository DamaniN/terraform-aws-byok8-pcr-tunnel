terraform {
  required_version = ">=1.5.6"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>5.26.0"
    }
    polaris = {
      source  = "rubrikinc/polaris"
      version = "=0.8.0-beta.16"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  profile = var.aws_profile
}

provider "aws" {
  region = "us-east-1"
  profile = var.aws_pcr_profile
  alias = "aws_pcr_account"
}

provider "polaris" {
  credentials = var.rsc_credentials
}

provider "kubernetes" {
  host                   = module.polaris-aws-cloud-native-customer-managed-exocompute-us-east-1.cluster_endpoint
  cluster_ca_certificate = module.polaris-aws-cloud-native-customer-managed-exocompute-us-east-1.cluster_ca_certificate
  token                  = module.polaris-aws-cloud-native-customer-managed-exocompute-us-east-1.cluster_token
  alias                  = "us-east-1"
}