# AWS S3 backend template for Terraform state.
#
# Prerequisites:
#   1. Create an S3 bucket (example: meridian-tfstate)
#   2. (Recommended) Create a DynamoDB table for state locking
#   3. Configure AWS credentials/profile
#
# Uncomment and adjust values before `terraform init`.

# terraform {
#   backend "s3" {
#     bucket         = "meridian-tfstate"
#     key            = "aws/terraform.tfstate"
#     region         = "ap-southeast-1"
#     encrypt        = true
#     dynamodb_table = "meridian-tf-locks"
#   }
# }
