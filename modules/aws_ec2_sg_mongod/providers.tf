# provider "aws" {
#   region = var.region
# }

terraform {
  required_version = ">= 1.3.7"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      #version = "~> 4.51.0"
      version = "~> 5.43.0"
    }
  }
}