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

## Quick Start with Act

### 1. Install Act

**macOS:**

```bash
brew install act
```

**Linux:**

```bash
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

### 2. Create Secrets File

```bash
cp .secrets.example .secrets
# Edit .secrets with your OPENAI_API_KEY
```

### 3. Configure Terraform Variables

Edit `infra/envs/production/terraform.tfvars` (or create from `terraform.tfvars.example`) and set your database credentials:

```hcl
db_username = "postgres"
db_password = "postgres"
db_name     = "postgres"
```

### 4. Full Setup (One Command)

```bash
act -j dev-full-setup --secret-file .secrets
```

This will:

- Initialize Terraform
- Create Kind cluster
- Deploy infrastructure (database, observability, ingress)
- Build all service images
- Deploy all services

### 5. Deploy a Service

Deploy a specific service with a version tag:

```bash
# Deploy server v1.0.0 to production
act -j deploy-service --input service=server --input version=v1.0.0 --input namespace=production --secret-file .secrets

# Deploy web to staging
act -j deploy-service --input service=web --input version=v2.0.0 --input namespace=staging --secret-file .secrets
```

### 6. Access Applications

| Service      | URL                                  | Description             |
| ------------ | ------------------------------------ | ----------------------- |
| Web          | https://devops-demo.local/           | React frontend          |
| Server API   | https://devops-demo.local/api        | tRPC API endpoints      |
| Resume Agent | https://devops-demo.local/resume-api | FastAPI resume analysis |

**Note**: Nginx Ingress provides routing for `.local` domains and can use self-signed certificates. Your browser may show a security warning - click "Advanced" and "Proceed" to accept the certificate.

### 7. Access Observability

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

### Infrastructure Workflows

```bash
# Initialize cluster and base infrastructure
act -j infra-init --input namespace=production --secret-file .secrets

# Plan infrastructure changes
act -j infra-plan --input namespace=production --secret-file .secrets

# Apply infrastructure changes
act -j infra-apply --input namespace=production --secret-file .secrets

# Destroy infrastructure
act -j infra-destroy --input namespace=production --secret-file .secrets
```

### Service Workflows

```bash
# Build a service image
act -j build-service --input service=server --input version=v1.0.0

# Deploy a service
act -j deploy-service --input service=server --input version=v1.0.0 --input namespace=production --secret-file .secrets
```

### Dev Team Workflows

```bash
# Build all services
act -j dev-build-all --input version=v1.0.0

# Full local setup (init + infra + build + deploy)
act -j dev-full-setup --input namespace=production --secret-file .secrets
```

## Commands (Makefile)

Alternative to GitHub Actions workflows, you can use Makefile commands directly:

### Initialization

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
make build-all       # Build all service images
make load-all        # Load images into Kind cluster
make deploy-all      # Deploy all services
```

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
# For Kind: Ensure images are loaded
make load-all

# For cloud: Ensure images are pushed to registry
# Check image pull policy in infra/modules/app/main.tf
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

## Next Steps

- See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture and design decisions
- Check `.github/workflows/` for CI/CD workflow details
- Review `infra/envs/production/terraform.tfvars.example` for configuration options

## Sources

- https://developer.hashicorp.com/terraform/tutorials
- https://github.com/hashicorp/terraform-guides/tree/master/infrastructure-as-code
- https://medium.com/schibsted-engineering/ultimate-terraform-project-structure-9fc7e79f6bc6
- https://github.com/MarcinKasprowicz/ultimate-terraform-folder-structure

## License

MIT
