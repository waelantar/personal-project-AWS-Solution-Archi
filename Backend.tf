terraform {
  backend "s3" {
    bucket = "tf-aws-architecture"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}