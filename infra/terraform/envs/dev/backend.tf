terraform {
  backend "s3" {
    bucket       = "infra-foundation-88"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
