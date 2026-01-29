# K8s Cluster Infrastructure

Demo: [Demo video](https://youtu.be/-FyedXjGiUw)

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

- **Kind** - Local Kubernetes cluster
- **Docker Registry** - Container image storage (`localhost:5555`)
- **Terraform** - Infrastructure as code
- **GitHub Actions** - CI/CD workflows

## Quick Start

### Local Development

```bash
# 1. Initialize environment (checks tools, starts Docker registry, creates Kind cluster)
make init

# 2. Configure secrets
# Edit infra/envs/production/terraform.tfvars with your secrets (especially openai_api_key)

# 3. Build all services
make build

# 4. Deploy infrastructure and services
make apply

# 5. Clean up everything when done
make clean
```

**What `make init` does:**

- Checks required tools (docker, terraform, kubectl, kind)
- Starts Docker registry on `http://localhost:5555`
- Creates Kind cluster named `devops-demo`
- Sets up `/etc/hosts` entry for `devops-demo.local`
- Creates `terraform.tfvars` from example if missing

### Verify Setup

```bash
# Check Docker registry is running
docker ps | grep docker-registry

# Check cluster status
make status

# View service images
kubectl get deployments -n production -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

### Access Applications

| Service      | URL                                  | Description             |
| ------------ | ------------------------------------ | ----------------------- |
| Web          | https://devops-demo.local/           | React frontend          |
| Server API   | https://devops-demo.local/api        | tRPC API endpoints      |
| Resume Agent | https://devops-demo.local/resume-api | FastAPI resume analysis |

**Note**: Browser may show a security warning for self-signed certificates. Click "Advanced" → "Proceed" to continue.

### View Logs

```bash
kubectl logs -f -n production -l app=server
kubectl logs -f -n production -l app=web
kubectl logs -f -n production -l app=resume-agent
```

## GitHub Actions Workflows

Workflows use `workflow_dispatch` triggers and can be run from the GitHub Actions UI.

**Prerequisites:**

- Remote Kind cluster running (set up via `make init` and `make apply`)
- `KUBECONFIG` secret configured in repository settings
- Docker registry accessible at `http://localhost:5555`

### Infrastructure Workflows

```bash
# Initialize cluster and base infrastructure
infra-init.yml      # Creates Kind cluster, deploys namespaces, database, ingress

# Apply all infrastructure
infra-apply.yml     # Applies all Terraform resources

# Destroy infrastructure
infra-destroy.yml   # Destroys infrastructure (optionally cluster)
```

### Service Workflows

```bash
# Build and push a service image
build.yml           # Builds single service (server, web, resume-agent, migration)

# Deploy a service
deploy.yml          # Deploys single service (builds, pushes, deploys via Terraform)
```

**Workflow Inputs:**

- `namespace`: `production`, `staging`, `testing` (default: `production`)
- `service`: `server`, `web`, `resume-agent` (required for build/deploy)
- `version`: Image tag (default: `latest`)
- `destroy_cluster`: Boolean (infra-destroy only, default: `false`)

**Note:** Deploying `server` automatically runs migrations first.

## Makefile Commands

### Main Commands

```bash
make init            # Initialize environment (tools, Docker registry, Kind cluster)
make build           # Build all service images and push to registry
make apply           # Apply infrastructure and deploy services
make clean           # Destroy infrastructure, cluster, and registry data
```

### Subcommands

```bash
# Infrastructure
make infra-init      # Initialize Terraform
make infra-plan      # Plan infrastructure changes
make infra-apply     # Apply infrastructure
make infra-destroy   # Destroy infrastructure

# Build & Deploy
make build-all       # Build all images (subcommand)
make load-all        # Load images into Kind cluster (local dev)
make deploy-all      # Deploy all services

# Utilities
make status          # Show cluster status
make restart         # Restart deployment (usage: make restart DEPLOYMENT=server)
make help            # Show all commands
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
docker ps | grep docker-registry

# Check registry accessibility
curl http://localhost:5555/v2/

# List repositories
curl http://localhost:5555/v2/_catalog

# Verify deployment images
kubectl get deployment -n production -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.template.spec.containers[0].image}{"\n"}{end}'

# Rebuild and push images
make build
```

### Docker Registry Issues

```bash
# Check registry container status
docker ps | grep docker-registry

# View registry logs
docker logs docker-registry

# Test registry connectivity
curl http://localhost:5555/v2/

# Restart registry
docker-compose -f docker-compose.registry.yml restart
```

### KUBECONFIG Not Configured

For GitHub Actions, export kubeconfig and add as secret:

```bash
# Export kubeconfig
kind export kubeconfig --name devops-demo > kubeconfig.yaml

# Add to GitHub: Settings → Secrets → Actions → New secret
# Name: KUBECONFIG
# Value: (paste entire kubeconfig.yaml contents)
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

## Docker Registry

The project uses a local Docker registry for container images.

**Registry Endpoint:** `http://localhost:5555`  
**Repository Format:** `localhost:5555/devops-demo-{namespace}/{service}:{version}`

**Examples:**

- `localhost:5555/devops-demo-production/server:latest`
- `localhost:5555/devops-demo-production/web:v1.0.0`

The registry is automatically started by `make init` and stopped/cleaned by `make clean`.

**Registry Management:**

```bash
# List repositories
curl http://localhost:5555/v2/_catalog

# List tags for a repository
curl http://localhost:5555/v2/devops-demo-production/server/tags/list

# Start registry manually
docker-compose -f docker-compose.registry.yml up -d

# Stop registry
docker-compose -f docker-compose.registry.yml down
```

## Next Steps

- See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture
- Review `infra/envs/production/terraform.tfvars.example` for configuration options
- Check `.github/workflows/` for workflow details

## Sources

- https://developer.hashicorp.com/terraform/tutorials
- https://github.com/hashicorp/terraform-guides/tree/master/infrastructure-as-code
- https://medium.com/schibsted-engineering/ultimate-terraform-project-structure-9fc7e79f6bc6
- https://github.com/MarcinKasprowicz/ultimate-terraform-folder-structure

## License

MIT
