#!/bin/bash
# Apply Terraform changes for a specific environment
# Usage: ./scripts/apply.sh <environment> [auto-approve]

set -e

# Get the directory where the script is located, then go to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="${1:-production}"
AUTO_APPROVE="${2:-false}"
ENV_DIR="$PROJECT_ROOT/infra/envs/${ENV}"

if [ ! -d "$ENV_DIR" ]; then
  echo "Error: Environment directory $ENV_DIR does not exist"
  exit 1
fi

if [ ! -f "$ENV_DIR/terraform.tfvars" ]; then
  echo "Error: terraform.tfvars not found in $ENV_DIR"
  echo "Copy terraform.tfvars.example to terraform.tfvars and configure it"
  exit 1
fi

echo "Applying Terraform changes for environment: $ENV"
cd "$ENV_DIR"

if [ "$AUTO_APPROVE" = "true" ] || [ "$AUTO_APPROVE" = "yes" ]; then
  terraform apply -var-file=terraform.tfvars -auto-approve
else
  terraform apply -var-file=terraform.tfvars
fi
