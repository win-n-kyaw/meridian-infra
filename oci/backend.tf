# OCI Object Storage with S3-compatible API for Terraform state.
#
# Prerequisites:
#   1. Create an OCI Object Storage bucket named "meridian-tfstate"
#   2. Generate a Customer Secret Key (S3-compatible credentials)
#   3. Set environment variables before running terraform init:
#        export AWS_ACCESS_KEY_ID="<oci_customer_secret_key_id>"
#        export AWS_SECRET_ACCESS_KEY="<oci_customer_secret_key>"
#
# The endpoint value must be provided at init time since backend blocks
# cannot reference variables:
#   terraform init -backend-config="endpoints={s3=\"https://<namespace>.compat.objectstorage.ap-singapore-1.oraclecloud.com\"}"

# terraform {
#   backend "s3" {
#     bucket   = "meridian-tfstate"
#     key      = "oci/terraform.tfstate"
#     region   = "ap-singapore-1"

#     # endpoint is set via -backend-config at init time
#     skip_region_validation      = true
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     skip_requesting_account_id  = true
#     use_path_style              = true
#   }
# }
