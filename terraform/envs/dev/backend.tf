
terraform {
  backend "s3" {
    bucket       = "abed-multi-region-infra-terraform-state"
    key          = "dev/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}