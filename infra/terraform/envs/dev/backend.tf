terraform {
  backend "s3" {
    bucket       = "ai-engineering-platform-tfstate-12345"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}