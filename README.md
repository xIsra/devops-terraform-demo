# K8s Cluster Infrastructure

Production-ready Infrastructure as Code (IaC) solution for deploying microservices to Kubernetes with centralized Terraform modules, observability stack, and CI/CD workflows.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (Any Provider)                 │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     Nginx Ingress Controller                   │  │
│  │                   (localhost:80 / localhost:443)               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                  │                                   │
│           ┌──────────────────────┼──────────────────────┐           │
│           ▼                      ▼                      ▼           │
│   ┌───────────────┐      ┌───────────────┐      ┌───────────────┐  │
│   │  /            │      │  /api         │      │  /resume-api  │  │
│   │  Web (React) │      │  Server (tRPC)│      │  Resume Agent │  │
│   │  ┌─────────┐  │      │  ┌─────────┐  │      │  ┌─────────┐  │  │
│   │  │ Pod 1   │  │      │  │ Pod 1   │  │      │  │ Pod 1   │  │  │
│   │  │ Pod 2   │  │      │  │ Pod 2   │  │      │  │ Pod 2   │  │  │
│   │  └─────────┘  │      │  └─────────┘  │      │  └─────────┘  │  │
│   └───────────────┘      └───────────────┘      └───────────────┘  │
│                                  │                                   │
│                                  ▼                                   │
│                        ┌──────────────────┐                         │
│                        │  PostgreSQL      │                         │
│                        │  (StatefulSet)   │                         │
│                        └──────────────────┘                         │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Observability Stack (monitoring namespace)        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │  │
│  │  │Prometheus│  │ Grafana  │  │   Loki   │  │ OpenTele │     │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Features

- **Centralized K8s Definitions**: All Kubernetes resources defined in Terraform using reusable modules
- **Multi-Environment Support**: Deploy to `production`, `staging`, or `testing` namespaces
- **Service Autonomy**: Each service owns its build process, Terraform handles deployments
- **Full Observability**: Prometheus metrics, Grafana dashboards, Loki logs, OpenTelemetry traces
- **Managed Database**: PostgreSQL StatefulSet simulating cloud-managed database
- **CI/CD Workflows**: Separate workflows for builds (auto), deploys (manual), and infrastructure
- **Cluster Agnostic**: Works with any Kubernetes cluster (Kind, EKS, GKE, AKS, etc.)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (for building images and running Kind)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (configured for your cluster)
- [Kind](https://kind.sigs.k8s.io/) (for local development) or any Kubernetes cluster (EKS, GKE, AKS, etc.)

### Quick Install (macOS)

```bash
brew install terraform kubectl kind
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
```

## Project Structure

```
asaph-devops-test/
├── Makefile                          # Root orchestrator
├── terraform/
│   ├── modules/                      # Reusable Terraform modules
│   │   ├── service/                  # Reusable service module
│   │   ├── namespace/                # Namespace module
│   │   ├── postgresql/               # PostgreSQL module
│   │   └── observability/            # Observability module
│   └── envs/                        # Environment-specific configs
│       └── production/              # Production environment
│           ├── main.tf               # Root module
│           ├── variables.tf          # Environment variables
│           ├── outputs.tf            # Outputs
│           ├── providers.tf          # Provider configs
│           ├── cluster.tf            # Kind cluster (local dev only)
│           ├── namespaces.tf         # Environment namespaces
│           ├── ingress.tf            # Nginx ingress controller
│           ├── database.tf           # PostgreSQL
│           ├── observability.tf      # Monitoring stack
│           ├── services-*.tf         # Service definitions
│           ├── terraform.tfvars      # Environment variables (gitignored)
│           └── terraform.tfvars.example  # Template
├── python/
│   └── resume-agent/
│       ├── Dockerfile
│       ├── Makefile                 # Build only
│       └── src/
├── typescript/
│   ├── Makefile                     # Build server/web
│   └── apps/
│       ├── server/
│       └── web/
└── .github/
    └── workflows/
        ├── build.yml                # Build workflow (auto/manual)
        ├── deploy.yml               # Deploy workflow (manual)
        └── infra.yml                # Infrastructure workflow (manual)
```

## Quick Start

### 1. Setup Secrets

```bash
cd terraform/envs/production
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your secrets
vim terraform.tfvars
```

Required secrets:

- `openai_api_key` - OpenAI API key for resume-agent
- `db_username`, `db_password`, `db_name` - Database credentials
- Note: `database_url` is automatically generated by Terraform from the database credentials

### 2. Setup Local Cluster (Kind)

For local development, ensure Kind is installed and create the cluster:

```bash
# Ensure Kind cluster exists (creates via Terraform if needed)
make ensure-cluster NAMESPACE=staging
```

This will:

- Check if the Kind cluster exists
- If not, create it via Terraform (manages cluster lifecycle)
- Set up kubeconfig for kubectl access

**Note:** The cluster is managed by Terraform, so it will be created automatically during `infra-apply` if it doesn't exist. However, running `ensure-cluster` first ensures the cluster is ready before initializing Terraform.

### 3. Deploy Infrastructure

```bash
# Initialize Terraform (runs in terraform/envs/production)
make infra-init NAMESPACE=production

# Plan changes
make infra-plan NAMESPACE=production

# Apply infrastructure (cluster, ingress, database, observability)
make infra-apply NAMESPACE=production
```

**Note:** All Terraform commands now run from `terraform/envs/<environment>/`. The Makefile automatically handles the correct directory.

### 3. Build and Deploy Services

```bash
# Build all service images
make build-all

# For Kind (local): Load images into cluster
make load-all

# For cloud: Push images to registry (ECR, GCR, etc.)
# docker push <registry>/resume-agent:latest
# docker push <registry>/server:latest
# docker push <registry>/web:latest

# Deploy all services
make deploy-all NAMESPACE=production

# Or use the full workflow (infra + build + deploy + health checks)
make all NAMESPACE=production
```

### 4. Access Applications

| Service      | URL                         | Description             |
| ------------ | --------------------------- | ----------------------- |
| Web          | http://localhost/           | React frontend          |
| Server API   | http://localhost/api        | tRPC API endpoints      |
| Resume Agent | http://localhost/resume-api | FastAPI resume analysis |

### 5. Access Observability

```bash
# Grafana dashboard
# Access directly: http://localhost:30080 (admin/admin)

# View logs
kubectl logs -f -n production -l app=server

# View metrics
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access Prometheus: http://localhost:9090
```

## Configuration

### Environment Variables

Deploy to different environments. Each environment has its own directory under `terraform/envs/`:

```bash
# Production (default)
make all NAMESPACE=production

# To add staging, create terraform/envs/staging/ with config files
# Then deploy with:
make all NAMESPACE=staging
```

### Service Configuration

Edit `terraform/envs/production/services-*.tf` to modify service settings:

```hcl
# terraform/envs/production/services-resume-agent.tf
module "resume_agent" {
  source = "../../modules/service"

  name      = "resume-agent"
  namespace = var.environment
  image     = "resume-agent:${var.resume_agent_version}"
  port      = 8000
  replicas  = var.resume_agent_replicas  # Adjust in tfvars

  # ... other config
}
```

### Variable Reference

| Variable                | Description              | Default       |
| ----------------------- | ------------------------ | ------------- |
| `environment`           | Deployment environment   | `production`  |
| `cluster_name`          | Cluster name (Kind only) | `devops-demo` |
| `resume_agent_version`  | Image tag                | `latest`      |
| `server_version`        | Image tag                | `latest`      |
| `web_version`           | Image tag                | `latest`      |
| `resume_agent_replicas` | Number of replicas       | `2`           |
| `server_replicas`       | Number of replicas       | `2`           |
| `web_replicas`          | Number of replicas       | `2`           |

## CI/CD Workflows

### Build Workflow (`build.yml`)

**Triggers:**

- Auto: Push/PR to `python/resume-agent/**`, `typescript/apps/**`
- Manual: `workflow_dispatch` with `service` parameter

**Usage:**

```bash
# Auto-triggered on code changes
# Or manually via GitHub UI: Actions → Build Service → Run workflow
```

### Deploy Workflow (`deploy.yml`)

**Triggers:**

- Manual only: `workflow_dispatch`

**Parameters:**

- `service`: `resume-agent`, `server`, or `web`
- `environment`: `production`, `staging`, `testing`
- `version`: Image tag/version

**Usage:**

```bash
# Via GitHub UI: Actions → Deploy Service → Run workflow
# Select service, environment, and version
```

### Infrastructure Workflow (`infra.yml`)

**Triggers:**

- Manual only: `workflow_dispatch`

**Parameters:**

- `action`: `plan`, `apply`, or `destroy`
- `environment`: Target environment

**Usage:**

```bash
# Via GitHub UI: Actions → Infrastructure → Run workflow
# Select action (plan/apply/destroy) and environment
```

### Running Locally with Act

[Act](https://github.com/nektos/act) allows running GitHub Actions locally:

```bash
# Install act
brew install act  # macOS

# Create .secrets file (gitignored)
cat > .secrets << EOF
OPENAI_API_KEY=sk-xxx
DATABASE_URL=postgresql://...
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_NAME=postgres
EOF

# Run workflows locally with act
act -j build --secret-file .secrets -W .github/workflows/build.yml
act -j deploy --secret-file .secrets -W .github/workflows/deploy.yml
act -j terraform --secret-file .secrets -W .github/workflows/infra.yml
```

## Makefile Commands

### Infrastructure

```bash
make infra-init          # Initialize Terraform
make infra-plan          # Plan infrastructure changes
make infra-apply         # Apply infrastructure (includes auto-import of existing resources)
make infra-destroy       # Destroy infrastructure
```

### Build & Deploy

```bash
make build-all           # Build all service images
make load-all            # Load images into Kind cluster
make deploy-all          # Deploy all services
```

### Full Workflow

```bash
make all                 # Complete deployment: infra + build + deploy + health checks
make clean               # Destroy cluster and infrastructure
```

### Utilities

```bash
make ensure-cluster      # Ensure Kind cluster exists (creates via Terraform if needed)
make status              # Show cluster status (pods and ingress)
make restart             # Restart a deployment (usage: make restart DEPLOYMENT=server)
make help                # Show available commands
```

## Design Decisions

### Why Centralized Terraform?

- **Single Source of Truth**: All K8s definitions in one place
- **No YAML Duplication**: Reusable modules eliminate repetition
- **Environment Consistency**: Same code deploys to all environments
- **Version Control**: Full history of infrastructure changes

### Why Service-Owned Builds?

- **Service Autonomy**: Teams control their build process
- **Technology Flexibility**: Each service uses its own tools
- **Independent CI**: Build failures don't block other services

### Why Separate Build/Deploy Workflows?

- **Build**: Fast feedback on code changes (auto-triggered)
- **Deploy**: Controlled releases (manual, requires approval)
- **Infrastructure**: Separate lifecycle from applications

### Why Cluster Agnostic?

- **Flexibility**: Works with any Kubernetes provider
- **Portability**: Same code for local dev and production
- **No Vendor Lock-in**: Easy to switch providers

## Services

### Resume Agent (`python/resume-agent/`)

FastAPI service for resume analysis using OpenAI.

- **Port**: 8000
- **Health**: `/api/v1/health`
- **Endpoints**: `/api/v1/analyze`, `/api/v1/generate-summary`, `/api/v1/tailor`

### Server (`typescript/apps/server/`)

Hono + tRPC API server.

- **Port**: 3000
- **Health**: `/`
- **Features**: tRPC endpoints, CORS, database integration

### Web (`typescript/apps/web/`)

React Router v7 frontend application.

- **Port**: 3000
- **Health**: `/`
- **Features**: TailwindCSS, PWA, dark mode

## Troubleshooting

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
make ensure-cluster NAMESPACE=production

# Or create cluster manually (not recommended - use Terraform)
kind create cluster --name devops-demo
```

### Images Not Found

```bash
# For Kind: Ensure images are loaded
make load-all

# For cloud: Ensure images are pushed to registry
# Check image pull policy in terraform/modules/service/main.tf
```

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resources
kubectl get ingress -n production

# View ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
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

## Cleanup

```bash
# Destroy everything (infrastructure + cluster)
make clean NAMESPACE=production

# Or destroy infrastructure only
make infra-destroy NAMESPACE=production
```

## License

MIT
