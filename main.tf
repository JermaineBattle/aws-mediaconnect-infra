terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-interoperability-event"
      ManagedBy   = "OpenTofu"
      Environment = var.environment
    }
  }
}

provider "awscc" {
  region = var.aws_region
}
