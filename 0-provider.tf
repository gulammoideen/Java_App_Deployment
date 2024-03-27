provider "aws" {
  alias = "provider"
  region = "__AWSREGION__"
  access_key = "__ACCESSKEY__"
  secret_key = "__SECRETKEY__"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}
