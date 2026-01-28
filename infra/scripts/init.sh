#!/bin/bash
# Initialize Terraform for a specific environment
# Usage: ./scripts/init.sh <environment>

set -e

# Get the directory where the script is located, then go to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="${1:-production}"
ENV_DIR="$PROJECT_ROOT/infra/envs/${ENV}"

if [ ! -d "$ENV_DIR" ]; then
  echo "Error: Environment directory $ENV_DIR does not exist"
  exit 1
fi

echo "Initializing Terraform for environment: $ENV"
cd "$ENV_DIR"
terraform init
