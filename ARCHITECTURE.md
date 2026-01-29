# Architecture & Design

Production-ready Infrastructure as Code (IaC) solution for deploying microservices to Kubernetes with centralized Terraform modules, observability stack, and CI/CD workflows.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (Any Provider)                 │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     Caddy Ingress Controller                    │  │
│  │              (devops-demo.local with automatic HTTPS)           │  │
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

## Project Structure

```
asaph-devops-test/
├── Makefile                          # Root orchestrator
├── infra/
│   ├── modules/                      # Reusable Terraform modules
│   │   ├── app/                      # Base Kubernetes service module
│   │   ├── web/                      # Web service wrapper module
│   │   ├── server/                   # Server service wrapper module
│   │   ├── resume-agent/             # Resume-agent service wrapper module
│   │   ├── server-migration/         # Database migration job module
│   │   ├── queue/                    # Queue module (placeholder)
│   │   ├── namespace/                # Namespace module
│   │   ├── postgresql/               # PostgreSQL module
│   │   └── observability/            # Observability module
│   ├── envs/                         # Environment-specific configs
│   │   └── production/               # Production environment
│   │       ├── main.tf                # Root module
│   │       ├── variables.tf          # Environment variables
│   │       ├── outputs.tf            # Outputs
│   │       ├── providers.tf          # Provider configs
│   │       ├── backend.tf            # Backend configuration
│   │       ├── namespaces.tf          # Environment namespaces
│   │       ├── ingress.tf            # Caddy ingress controller
│   │       ├── database.tf            # PostgreSQL
│   │       ├── observability.tf       # Monitoring stack
│   │       ├── web.tf                 # Web service
│   │       ├── server.tf              # Server service
│   │       ├── server-migration.tf    # Migration job
│   │       ├── resume-agent.tf        # Resume-agent service
│   │       ├── terraform.tfvars       # Environment variables (gitignored)
│   │       └── terraform.tfvars.example  # Template
│   ├── shared/                       # Shared configuration
│   └── scripts/                     # Helper scripts
│       ├── init.sh
│       ├── plan.sh
│       ├── apply.sh
│       └── destroy.sh
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

## Design Decisions

### Why Centralized Terraform?

- **Single Source of Truth**: All K8s definitions in one place
- **No YAML Duplication**: Reusable modules eliminate repetition
- **Environment Consistency**: Same code deploys to all environments
- **Version Control**: Full history of infrastructure changes
- **Service Wrapper Modules**: Encapsulate service-specific defaults while reusing base `app` module

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
- **Health**: `/health`
- **Features**: tRPC endpoints, CORS, database integration

### Web (`typescript/apps/web/`)

React Router v7 frontend application.

- **Port**: 3000
- **Health**: `/`
- **Features**: TailwindCSS, PWA, dark mode

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
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_NAME=postgres
EOF

# Run workflows locally with act
act -j build --secret-file .secrets -W .github/workflows/build.yml
act -j deploy --secret-file .secrets -W .github/workflows/deploy.yml
act -j terraform --secret-file .secrets -W .github/workflows/infra.yml
```

## Configuration

### Environment Variables

Deploy to different environments. Each environment has its own directory under `infra/envs/`:

```bash
# Production (default)
make all NAMESPACE=production

# To add staging, create infra/envs/staging/ with config files
# Then deploy with:
make all NAMESPACE=staging
```

### Service Configuration

Edit service files in `infra/envs/production/` to modify service settings:

```hcl
# infra/envs/production/resume-agent.tf
module "resume_agent" {
  source = "../../modules/resume-agent"

  namespace     = var.environment
  image_version = var.resume_agent_version
  replicas      = var.resume_agent_replicas  # Adjust in tfvars
  openai_api_key = var.openai_api_key
  openai_model   = var.openai_model
}
```

Service-specific wrapper modules encapsulate defaults:

- `modules/web` - Web frontend service
- `modules/server` - Server API service
- `modules/resume-agent` - Resume agent service
- `modules/server-migration` - Database migration job

All wrapper modules delegate to `modules/app` for common Kubernetes resources (deployment, service, ingress, secrets, configmaps).

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
