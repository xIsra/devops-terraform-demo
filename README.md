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
- **Docker Registry** (deployed in-cluster) for container images
- **Terraform** for infrastructure as code
- **GitHub Actions** for CI/CD workflows

### Docker Registry

A local Docker registry is automatically deployed in the cluster to store container images. Images are:

- Built locally or in CI
- Pushed to `localhost:5000` (via port-forward) or the registry service
- Pulled by pods using the cluster-internal registry URL

**Registry Access:**

- **Cluster-internal**: `docker-registry.docker-registry.svc.cluster.local:5000`
- **External (CI/CD)**: `localhost:5000` (via kubectl port-forward)

## Quick Start

### Option 1: Local Development (Makefile)

```bash
# 1. Initialize environment
make init

# 2. Configure secrets
# Edit infra/envs/production/terraform.tfvars with your secrets

# 3. Deploy everything
make all
```

### Option 2: GitHub Actions (Remote Cluster)

#### 1. Set Up Remote Cluster

On the machine where the cluster will run:

```bash
# Initialize and create cluster
make init
make infra-apply

# Or manually:
cd infra/envs/production
terraform init
terraform apply -var-file=terraform.tfvars -auto-approve
```

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
- Deploy Docker registry
- Deploy infrastructure (database, observability, ingress)
- Build all service images
- Push images to registry
- Deploy all services

### 5. Verify Setup

```bash
# Check registry is running
kubectl get pods -n docker-registry

# Check services are using registry images
kubectl get deployments -n production -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.template.spec.containers[0].image}{"\n"}{end}'

# Should show images like:
# server: docker-registry.docker-registry.svc.cluster.local:5000/server:latest
# web: docker-registry.docker-registry.svc.cluster.local:5000/web:latest
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

### 8. Access Observability

```bash
# Grafana dashboard
# Access directly: http://localhost:30080 (admin/admin)

# View logs
kubectl logs -f -n production -l app=server

# View metrics
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access Prometheus: http://localhost:9090
```

## Available Workflows

All workflows can be run locally with `act` or in GitHub Actions CI. Workflows use `workflow_dispatch` triggers with configurable inputs.

**Note:** All workflows require the `KUBECONFIG` secret to be configured in GitHub Actions (or `.secrets` file for local testing with `act`).

### Infrastructure Workflows

Manage cluster and base infrastructure:

```bash
# Initialize cluster and base infrastructure (namespaces, database, observability)
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
# Build a service image and push to registry (server, web, resume-agent, or migration)
act -j build-service --input service=server --input version=v1.0.0 --secret-file .secrets

# Deploy a service with version tag (builds, pushes to registry, then deploys)
act -j deploy-service --input service=server --input version=v1.0.0 --input namespace=production --secret-file .secrets

# Deploy to staging
act -j deploy-service --input service=web --input version=v2.0.0 --input namespace=staging --secret-file .secrets
```

**Service options:** `server`, `web`, `resume-agent`  
**Note:**

- Deploying `server` automatically runs migrations first
- All images are pushed to the Docker registry before deployment
- Workflows automatically port-forward the registry for image pushes

### Dev Team Workflows

Convenience workflows for development:

```bash
# Build all services with the same version tag and push to registry
act -j dev-build-all --input version=v1.0.0 --secret-file .secrets

# Complete local setup (init + infra + build + push + deploy)
# This is the recommended way to get started
act -j dev-full-setup --input namespace=production --secret-file .secrets
```

**What happens:**

1. Creates/verifies Kind cluster exists
2. Deploys Docker registry
3. Deploys base infrastructure (database, observability, ingress)
4. Builds all service images
5. Pushes images to registry
6. Deploys all services

### Workflow Inputs

Most workflows support these common inputs:

- `namespace`: Target environment (`production`, `staging`, `testing`) - default: `production`
- `version`: Image version/tag (e.g., `v1.0.0`) - default: `latest`
- `service`: Service name (`server`, `web`, `resume-agent`) - required for service workflows
- `destroy_cluster`: Destroy Kind cluster (infra-destroy only) - default: `false`

### Running Workflows in GitHub Actions

**Prerequisites:**

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
- Port-forward registry service for image pushes
- Build and push images to registry
- Deploy services using registry images

## Commands (Makefile)

Alternative to GitHub Actions workflows, you can use Makefile commands directly:

### Initialization

```bash
make init            # Initialize development environment (tools, /etc/hosts, config)
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
make build-all       # Build all service images (local only, doesn't push to registry)
make load-all        # Load images into Kind cluster (legacy - use registry instead)
make deploy-all      # Deploy all services (uses registry images)
```

**Note:** For CI/CD workflows, images are automatically pushed to the Docker registry. The `load-all` command is for local development only. For production, use the registry workflow.

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
# Check registry is running
kubectl get pods -n docker-registry

# Check if images exist in registry
kubectl port-forward -n docker-registry svc/docker-registry-nodeport 5000:5000 &
curl http://localhost:5000/v2/_catalog

# Verify deployment image references
kubectl get deployment -n production -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.template.spec.containers[0].image}{"\n"}{end}'

# For local development: Load images directly (legacy method)
make load-all

# For CI/CD: Ensure workflows pushed images to registry
# Check workflow logs for "Pushed ... to registry" messages
```

### Registry Connection Issues

```bash
# Check registry pod status
kubectl get pods -n docker-registry

# View registry logs
kubectl logs -n docker-registry -l app=docker-registry

# Test registry connectivity
kubectl port-forward -n docker-registry svc/docker-registry-nodeport 5000:5000 &
curl http://localhost:5000/v2/

# Verify registry service
kubectl get svc -n docker-registry
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

## Docker Registry Details

### Registry Configuration

The Docker registry is automatically deployed as part of the infrastructure:

- **Namespace**: `docker-registry`
- **Storage**: 10Gi persistent volume
- **Access**:
  - Cluster-internal: `docker-registry.docker-registry.svc.cluster.local:5000`
  - External (NodePort): Port 30500 → 5000
  - CI/CD: Port-forwarded to `localhost:5000`

### Image Naming Convention

Images in the registry follow this pattern:

```
{registry_url}/{service}:{version}
```

Examples:

- `docker-registry.docker-registry.svc.cluster.local:5000/server:latest`
- `docker-registry.docker-registry.svc.cluster.local:5000/web:v1.0.0`
- `docker-registry.docker-registry.svc.cluster.local:5000/resume-agent:latest`

### Registry Management

```bash
# List images in registry
kubectl port-forward -n docker-registry svc/docker-registry-nodeport 5000:5000 &
curl http://localhost:5000/v2/_catalog

# List tags for a specific image
curl http://localhost:5000/v2/{image}/tags/list

# Delete registry (will remove all images)
kubectl delete namespace docker-registry
```

## Next Steps

- See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture and design decisions
- Check `.github/workflows/` for CI/CD workflow details
- Review `infra/envs/production/terraform.tfvars.example` for configuration options
- Review `infra/modules/docker-registry/` for registry configuration

## Sources

- https://developer.hashicorp.com/terraform/tutorials
- https://github.com/hashicorp/terraform-guides/tree/master/infrastructure-as-code
- https://medium.com/schibsted-engineering/ultimate-terraform-project-structure-9fc7e79f6bc6
- https://github.com/MarcinKasprowicz/ultimate-terraform-folder-structure

## License

MIT
