terraform {
  required_version = ">=1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

locals {
  default_tags = {
    Project     = "multi-region-infra"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"

  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "usw2"
  region = "us-west-2"

  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "euw1"
  region = "eu-west-1"

  default_tags {
    tags = local.default_tags
  }
}