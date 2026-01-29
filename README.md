# K8s Cluster Infrastructure

Quick start guide for deploying microservices to Kubernetes. See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture and design decisions.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (for building images and running Kind)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (configured for your cluster)
- [Kind](https://kind.sigs.k8s.io/) (for local development) or any Kubernetes cluster (EKS, GKE, AKS, etc.)
- [Act](https://github.com/nektos/act) (for running GitHub Actions locally)

### Quick Install (macOS)

```bash
brew install terraform kubectl kind act
```

### Quick Install (Linux)

```bash
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Act
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

## Architecture Overview

This project uses:

- **Kind** for local Kubernetes cluster
- **Image Registry** (Docker registry) for container images
- **Terraform** for infrastructure as code
- **GitHub Actions** for CI/CD workflows

### Image Registry (Docker Registry)

Container images are stored in a Docker registry running locally:

- Images are built locally or in CI
- Pushed to the Docker registry using standard Docker commands
- Pulled by pods using registry repository URLs

**Prerequisites:**

- Docker registry must be running separately (see setup below)

**Image Registry Access:**

- **Registry Endpoint**: `http://localhost:5555`
- **Registry URL**: `localhost:5555` (for Docker operations)
- **Repository Format**: `localhost:5555/devops-demo-{env}/{service}:{version}`

## Quick Start

### Option 1: Local Development (Makefile)

```bash
# 1. Initialize environment (starts Kind cluster and LocalStack)
make init

# This will:
# - Check all required tools are installed
# - Start LocalStack (image registry) via docker-compose
# - Create Kind cluster if it doesn't exist
# - Set up /etc/hosts entry for ingress
# - Create terraform.tfvars from example if needed

# 2. Configure secrets (if not already done)
# Edit infra/envs/production/terraform.tfvars with your secrets

# 3. Deploy everything
make all
```

**Note:** `make init` automatically starts:

- **LocalStack** (image registry) on `http://localhost:4566`
- **Kind cluster** named `devops-demo`

If you need to start LocalStack separately:

```bash
docker-compose -f docker-compose.registry.yml up -d
```

### Option 2: GitHub Actions (Remote Cluster)

#### 1. Set Up LocalStack and Remote Cluster

On the machine where the cluster will run:

```bash
# Initialize environment (starts LocalStack and creates Kind cluster)
make init

# Deploy infrastructure
make infra-apply

# Or manually:
cd infra/envs/production
terraform init
terraform apply -var-file=terraform.tfvars -auto-approve
```

**Note:** `make init` will automatically start LocalStack and create the Kind cluster if they don't exist.

#### 2. Export Kubeconfig for GitHub Actions

```bash
# Export kubeconfig from the cluster
kind export kubeconfig --name devops-demo > kubeconfig.yaml

# Or if kubectl is already configured:
kubectl config view --flatten > kubeconfig.yaml
```

#### 3. Add GitHub Secret

In your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `KUBECONFIG`
4. Value: Paste the entire contents of `kubeconfig.yaml`
5. Click **Add secret**

#### 4. Run Workflows

**Via GitHub Actions UI:**

1. Go to **Actions** tab
2. Select workflow (e.g., "Dev Full Setup")
3. Click **Run workflow**
4. Choose namespace and run

**Via GitHub CLI:**

```bash
gh workflow run dev-full-setup.yml -f namespace=production
```

**Via Act (local testing):**

```bash
# Create .secrets file
echo "KUBECONFIG=$(cat kubeconfig.yaml | base64)" > .secrets
echo "OPENAI_API_KEY=sk-your-key" >> .secrets

# Run workflow
act -j dev-full-setup --secret-file .secrets --input namespace=production
```

### Option 3: Act (Local Testing)

#### 1. Install Act

**macOS:**

```bash
brew install act
```

**Linux:**

```bash
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

#### 2. Create Secrets File

```bash
cp .secrets.example .secrets
# Edit .secrets with your OPENAI_API_KEY and KUBECONFIG
```

#### 3. Configure Terraform Variables

Edit `infra/envs/production/terraform.tfvars` (or create from `terraform.tfvars.example`):

```hcl
db_username = "postgres"
db_password = "postgres"
db_name     = "postgres"
openai_api_key = "sk-your-key-here"
```

#### 4. Full Setup (One Command)

```bash
act -j dev-full-setup --secret-file .secrets --input namespace=production
```

This will:

- Initialize Terraform
- Create Kind cluster (if not exists)
- Deploy image registry repositories (ECR via LocalStack)
- Deploy infrastructure (database, ingress)
- Build all service images
- Push images to image registry
- Deploy all services

### 5. Verify Setup

```bash
# Check Docker registry is running
docker ps | grep docker-registry

# Check Docker registry is accessible
curl http://localhost:5555/v2/

# Check services are using image registry images
kubectl get deployments -n production -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.template.spec.containers[0].image}{"\n"}{end}'

# Should show images like:
# server: localhost:5555/devops-demo-production/server:latest
# web: localhost:5555/devops-demo-production/web:latest
```

### 6. Deploy a Service

Deploy a specific service with a version tag:

```bash
# Deploy server v1.0.0 to production
act -j deploy-service --input service=server --input version=v1.0.0 --input namespace=production --secret-file .secrets

# Deploy web to staging
act -j deploy-service --input service=web --input version=v2.0.0 --input namespace=staging --secret-file .secrets
```

### 7. Access Applications

| Service      | URL                                  | Description             |
| ------------ | ------------------------------------ | ----------------------- |
| Web          | https://devops-demo.local/           | React frontend          |
| Server API   | https://devops-demo.local/api        | tRPC API endpoints      |
| Resume Agent | https://devops-demo.local/resume-api | FastAPI resume analysis |

**Note**: Nginx Ingress provides routing for `.local` domains and can use self-signed certificates. Your browser may show a security warning - click "Advanced" and "Proceed" to accept the certificate.

### 8. View Logs

```bash
# View logs
kubectl logs -f -n production -l app=server
kubectl logs -f -n production -l app=web
kubectl logs -f -n production -l app=resume-agent
```

## Available Workflows

All workflows can be run locally with `act` or in GitHub Actions CI. Workflows use `workflow_dispatch` triggers with configurable inputs.

**Note:** All workflows require the `KUBECONFIG` secret to be configured in GitHub Actions (or `.secrets` file for local testing with `act`).

### Infrastructure Workflows

Manage cluster and base infrastructure:

```bash
# Initialize cluster and base infrastructure (namespaces, database, ingress)
act -j infra-init --input namespace=production --secret-file .secrets

# Preview infrastructure changes before applying
act -j infra-plan --input namespace=production --secret-file .secrets

# Apply infrastructure changes
act -j infra-apply --input namespace=production --secret-file .secrets

# Destroy infrastructure (optionally destroy cluster)
act -j infra-destroy --input namespace=production --input destroy_cluster=false --secret-file .secrets
```

**Available namespaces:** `production`, `staging`, `testing`

### Service Workflows

Build and deploy individual services:

```bash
# Build a service image and push to image registry (server, web, resume-agent, or migration)
act -j build-service --input service=server --input version=v1.0.0 --secret-file .secrets

# Deploy a service with version tag (builds, pushes to image registry, then deploys)
act -j deploy-service --input service=server --input version=v1.0.0 --input namespace=production --secret-file .secrets

# Deploy to staging
act -j deploy-service --input service=web --input version=v2.0.0 --input namespace=staging --secret-file .secrets
```

**Service options:** `server`, `web`, `resume-agent`  
**Note:**

- Deploying `server` automatically runs migrations first
- All images are pushed to the Docker registry before deployment
- Workflows verify Docker registry accessibility and push images using standard Docker commands

### Dev Team Workflows

Convenience workflows for development:

```bash
# Build all services with the same version tag and push to image registry
act -j dev-build-all --input version=v1.0.0 --secret-file .secrets

# Complete local setup (init + infra + build + push + deploy)
# This is the recommended way to get started
act -j dev-full-setup --input namespace=production --secret-file .secrets
```

**What happens:**

1. Creates/verifies Kind cluster exists
2. Deploys image registry (Docker registry)
3. Deploys base infrastructure (database, ingress)
4. Builds all service images
5. Pushes images to image registry
6. Deploys all services

### Workflow Inputs

Most workflows support these common inputs:

- `namespace`: Target environment (`production`, `staging`, `testing`) - default: `production`
- `version`: Image version/tag (e.g., `v1.0.0`) - default: `latest`
- `service`: Service name (`server`, `web`, `resume-agent`) - required for service workflows
- `destroy_cluster`: Destroy Kind cluster (infra-destroy only) - default: `false`

### Running Workflows in GitHub Actions

**Prerequisites:**

- Docker registry must be running (for image registry)
- Remote Kind cluster must be running (set up via `make infra-apply` or manually)
- `KUBECONFIG` secret must be configured in repository settings

**Trigger workflows:**

1. Go to **Actions** tab
2. Select the workflow
3. Click **Run workflow**
4. Fill in inputs (namespace, version, service, etc.)
5. Click **Run workflow**

Workflows will:

- Connect to remote cluster using `KUBECONFIG` secret
- Verify Docker registry is accessible (endpoint: http://localhost:5555)
- Build and push images to image registry (ECR)
- Deploy services using image registry images

## Commands (Makefile)

Alternative to GitHub Actions workflows, you can use Makefile commands directly:

### Initialization

```bash
make init            # Initialize environment (starts Kind cluster and LocalStack)
```

### Infrastructure

```bash
make infra-init      # Initialize Terraform (runs init automatically)
make infra-plan      # Plan infrastructure changes
make infra-apply     # Apply infrastructure (includes auto-import of existing resources)
make infra-destroy   # Destroy infrastructure
```

### Build & Deploy

```bash
make build-all       # Build all service images (local only, doesn't push to image registry)
make load-all        # Load images into Kind cluster (legacy - use image registry instead)
make deploy-all      # Deploy all services (uses image registry images)
```

**Note:** For CI/CD workflows, images are automatically pushed to the Docker registry. The `load-all` command is for local development only. For production, use the image registry workflow.

### Full Workflow

```bash
make all             # Complete deployment: infra + build + deploy + health checks
make clean           # Destroy cluster and infrastructure
```

### Utilities

```bash
make ensure-cluster  # Ensure Kind cluster exists (creates via Terraform if needed)
make status          # Show cluster status (pods and ingress)
make restart         # Restart a deployment (usage: make restart DEPLOYMENT=server)
make help            # Show available commands
```

## Common Issues

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n production

# View pod logs
kubectl logs -n production -l app=server

# Describe pod for events
kubectl describe pod -n production <pod-name>
```

### Cluster Not Found

```bash
# Ensure Kind cluster exists
make ensure-cluster

# Or create cluster manually (not recommended - use Terraform)
kind create cluster --name devops-demo
```

### Images Not Found

```bash
# Check Docker registry is running
docker ps | grep docker-registry

# Check Docker registry is accessible
curl http://localhost:5555/v2/

# List repositories in the registry
curl http://localhost:5555/v2/_catalog

# List tags for a repository
curl http://localhost:5555/v2/devops-demo-production/server/tags/list

# Verify deployment image references
kubectl get deployment -n production -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.template.spec.containers[0].image}{"\n"}{end}'

# For local development: Load images directly (legacy method)
make load-all

# For CI/CD: Ensure workflows pushed images to image registry
# Check workflow logs for "Pushed ... to image registry" messages
```

### Image Registry Connection Issues

```bash
# Check Docker registry container status
docker ps | grep docker-registry

# View Docker registry logs
docker logs docker-registry

# Test Docker registry connectivity
curl http://localhost:5555/v2/

# Test Docker registry API
curl http://localhost:5555/v2/

# Verify registry connectivity
aws configure list
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

### KUBECONFIG Not Configured

If workflows fail with "No nodes found in cluster":

```bash
# Export kubeconfig from remote cluster
kind export kubeconfig --name devops-demo > kubeconfig.yaml

# Add to GitHub secrets:
# Settings → Secrets → Actions → New secret
# Name: KUBECONFIG
# Value: (paste entire kubeconfig.yaml contents)

# For local testing with act:
echo "KUBECONFIG=$(cat kubeconfig.yaml | base64)" >> .secrets
```

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resources
kubectl get ingress -n production

# View ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Verify domain is in /etc/hosts
grep devops-demo.local /etc/hosts

# If missing, add it:
echo "127.0.0.1 devops-demo.local" | sudo tee -a /etc/hosts
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl get pods -n database

# Test connection
kubectl exec -it -n database postgresql-0 -- psql -U postgres -d postgres

# Verify service
kubectl get svc -n database
```

### SSL Certificate Warnings

When accessing `https://devops-demo.local`, browsers show a security warning because the Nginx Ingress controller uses self-signed certificates for `.local` domains. This is expected for local development:

1. Click "Advanced" or "Show Details"
2. Click "Proceed to devops-demo.local" or "Accept the Risk and Continue"

The certificate is valid and secure for local development.

### Terraform State Issues

If Terraform state is out of sync:

```bash
# Refresh state
cd infra/envs/production
terraform refresh -var-file=terraform.tfvars

# Remove stale resources from state
terraform state rm <resource-address>

# Import existing resources
terraform import <resource-address> <resource-id>
```

### Migration Job Failing

```bash
# Check migration job status
kubectl get jobs -n production

# View migration logs
SERVER_VERSION=$(grep '^server_version' infra/envs/production/terraform.tfvars | cut -d'"' -f2)
MIGRATION_JOB_NAME=server-migration-$(echo $SERVER_VERSION | tr '.' '-')
kubectl logs job/$MIGRATION_JOB_NAME -n production

# Restart migration
kubectl delete job $MIGRATION_JOB_NAME -n production
make deploy-all  # Will recreate the job
```

## Cleanup

```bash
# Destroy everything (infrastructure + cluster)
make clean

# Or destroy infrastructure only
make infra-destroy
```

## Image Registry Details

The image registry is implemented using AWS ECR, simulated locally via LocalStack. This provides a production-like container registry experience.

### LocalStack Setup

**Important:** ECR requires LocalStack Pro (not available in the free community edition). You have two options:

#### Option 1: Use LocalStack Pro (Recommended for ECR)

1. Get a free trial token at https://app.localstack.cloud/
2. Set the token in your environment:
   ```bash
   export LOCALSTACK_AUTH_TOKEN=your-token-here
   ```
3. Start LocalStack:
   ```bash
   docker-compose -f docker-compose.localstack.yml up -d
   ```

#### Option 2: Use LocalStack Community (ECR will not work)

If you don't have a LocalStack Pro token, you can still run LocalStack, but ECR operations will fail. You'll need to use a different registry solution (see "Alternative: Simple Docker Registry" below).

**Starting LocalStack:**

LocalStack is automatically started by `make init`. If you need to start it manually:

```bash
# Using docker-compose (recommended)
docker-compose -f docker-compose.localstack.yml up -d

# Verify it's running
curl http://localhost:4566/_localstack/health

# Test ECR access (requires Pro)
aws --endpoint-url=http://localhost:4566 ecr describe-repositories --region us-east-1
```

**Note:** `make init` will automatically start LocalStack if it's not already running.

### Image Registry Configuration

Image registry repositories are created via Terraform using the `image_registry` module:

- **LocalStack Endpoint**: `http://localhost:4566`
- **AWS Region**: `us-east-1` (for LocalStack)
- **Repository Prefix**: `devops-demo-{environment}` (e.g., `devops-demo-production`)

### Image Naming Convention

Images in the registry follow this pattern:

```
{registry_url}/{repository_prefix}/{service}:{version}
```

Examples:

- `localhost:4566/devops-demo-production/server:latest`
- `localhost:4566/devops-demo-production/web:v1.0.0`
- `localhost:4566/devops-demo-production/resume-agent:latest`

### Image Registry Management

```bash
# List all repositories
aws --endpoint-url=http://localhost:4566 ecr describe-repositories --region us-east-1

# List images in a repository
aws --endpoint-url=http://localhost:4566 ecr list-images \
  --repository-name devops-demo-production/server \
  --region us-east-1

# Authenticate Docker with image registry
aws ecr get-login-password --endpoint-url=http://localhost:4566 --region us-east-1 | \
  docker login --username AWS --password-stdin localhost:4566

# Delete a repository (will remove all images)
aws --endpoint-url=http://localhost:4566 ecr delete-repository \
  --repository-name devops-demo-production/server \
  --force \
  --region us-east-1
```

### Switching to Real AWS ECR

To use real AWS ECR instead of LocalStack:

1. Update `infra/envs/production/variables.tf`:

   ```hcl
   localstack_endpoint = "https://123456789012.dkr.ecr.us-east-1.amazonaws.com"
   aws_region = "us-east-1"
   ```

2. Configure AWS credentials (remove test credentials from module)

3. Update workflows to use real AWS credentials instead of test values

The `image_registry` module abstracts the implementation, making it easy to switch between LocalStack and real AWS ECR.

## Next Steps

- See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture and design decisions
- Check `.github/workflows/` for CI/CD workflow details
- Review `infra/envs/production/terraform.tfvars.example` for configuration options
- Review `infra/modules/image-registry/` for image registry configuration
- Review `docker-compose.registry.yml` for Docker registry setup

## Sources

- https://developer.hashicorp.com/terraform/tutorials
- https://github.com/hashicorp/terraform-guides/tree/master/infrastructure-as-code
- https://medium.com/schibsted-engineering/ultimate-terraform-project-structure-9fc7e79f6bc6
- https://github.com/MarcinKasprowicz/ultimate-terraform-folder-structure

## License

MIT
