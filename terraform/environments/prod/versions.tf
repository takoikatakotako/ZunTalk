terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.25.0"
    }
  }

  backend "s3" {
    bucket  = "charalarm.terraform.state"
    key     = "zuntalk-production/terraform.tfstate"
    region  = "ap-northeast-1"
    profile = "charalarm-management-sso"
  }
}

provider "aws" {
  region  = var.region
  profile = "charalarm-production-sso"

  default_tags {
    tags = {
      Project     = "ZunTalk"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
