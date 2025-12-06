terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "zuntalk-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "zuntalk-terraform-lock"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "ZunTalk"
      Environment = "prod"
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_ecr_repository" "backend" {
  name = "zuntalk-backend"
}

module "lambda" {
  source = "../../modules/lambda"

  function_name = "zuntalk-backend-prod"
  image_uri     = "${data.aws_ecr_repository.backend.repository_url}:prod-latest"
  timeout       = 30
  memory_size   = 1024

  environment_variables = {
    OPENAI_API_KEY = var.openai_api_key
    PORT           = "8080"
    ENV            = "prod"
  }

  log_retention_days = 30

  enable_function_url    = true
  function_url_auth_type = "NONE"

  cors_allow_credentials = true
  cors_allow_origins     = ["*"]
  cors_allow_methods     = ["*"]
  cors_allow_headers     = ["*"]

  tags = {
    Name = "zuntalk-backend-prod"
  }
}
