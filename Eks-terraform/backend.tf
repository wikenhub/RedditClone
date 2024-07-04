terraform {
  backend "s3" {
    bucket = "henry-reddit-clone" # Replace with your actual S3 bucket name
    key    = "EKS/terraform.tfstate"
    region = "ap-northeast-2" # Replace with your actual region
  }
}
