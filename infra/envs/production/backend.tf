# -----------------------------------------------------------------------------
# Backend Configuration
# State storage configuration for this environment
# -----------------------------------------------------------------------------

# Currently using local state (default)
# To use remote backend (S3, GCS, AzureRM, etc.), uncomment and configure:

# terraform {
#   backend "s3" {
#     bucket         = "terraform-state-bucket"
#     key            = "production/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# For local state, no backend block is needed (default behavior)
