# -----------------------------------------------------------------------------
# Shared Local Values
# Common values used across environments
# -----------------------------------------------------------------------------

locals {
  # Common tags for all resources
  common_tags = {
    "managed-by" = "terraform"
    "project"    = "devops-demo"
  }

  # Naming conventions
  name_prefix = "devops-demo"
}
