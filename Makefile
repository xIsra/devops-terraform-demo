.PHONY: all init infra-init infra-plan infra-apply infra-destroy build-all load-all deploy-all clean status restart ensure-cluster setup-kubeconfig help

CLUSTER_NAME ?= devops-demo
NAMESPACE ?= production
INGRESS_HOST ?= devops-demo.local
TF_DIR := infra
TF_ENV_DIR := $(CURDIR)/$(TF_DIR)/envs/$(NAMESPACE)
TF_VARS := $(TF_ENV_DIR)/terraform.tfvars
TF_SCRIPTS := $(CURDIR)/$(TF_DIR)/scripts
TF_VARS_EXAMPLE := $(TF_ENV_DIR)/terraform.tfvars.example

# === INITIALIZATION ===
init:
	@echo "=== Initializing Development Environment ==="
	@echo ""
	@# Check required tools
	@echo "Checking required tools..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ Error: docker is not installed. Install from https://docs.docker.com/get-docker/"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || command -v docker compose >/dev/null 2>&1 || { echo "❌ Error: docker-compose is not installed."; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "❌ Error: terraform is not installed. Install from https://developer.hashicorp.com/terraform/downloads"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ Error: kubectl is not installed. Install from https://kubernetes.io/docs/tasks/tools/"; exit 1; }
	@command -v kind >/dev/null 2>&1 || { echo "❌ Error: kind is not installed. Install from https://kind.sigs.k8s.io/"; exit 1; }
	@echo "✅ All required tools are installed"
	@echo ""
	@# Check Docker is running
	@echo "Checking Docker daemon..."
	@docker info >/dev/null 2>&1 || { echo "❌ Error: Docker daemon is not running. Start Docker and try again."; exit 1; }
	@echo "✅ Docker daemon is running"
	@echo ""
	@# Setup /etc/hosts entry
	@echo "Setting up /etc/hosts entry for $(INGRESS_HOST)..."
	@if grep -q "$(INGRESS_HOST)" /etc/hosts 2>/dev/null; then \
		echo "✅ $(INGRESS_HOST) already exists in /etc/hosts"; \
	else \
		echo "Adding $(INGRESS_HOST) to /etc/hosts (requires sudo)..."; \
		echo "127.0.0.1 $(INGRESS_HOST)" | sudo tee -a /etc/hosts >/dev/null && \
		echo "✅ Added $(INGRESS_HOST) to /etc/hosts" || \
		{ echo "⚠️  Warning: Could not add to /etc/hosts. You may need to run manually:"; \
		  echo "   echo '127.0.0.1 $(INGRESS_HOST)' | sudo tee -a /etc/hosts"; }; \
	fi
	@echo ""
	@# Check/create terraform.tfvars
	@echo "Checking Terraform configuration..."
	@if [ ! -f $(TF_VARS) ]; then \
		if [ -f $(TF_VARS_EXAMPLE) ]; then \
			echo "⚠️  $(TF_VARS) not found. Creating from example..."; \
			cp $(TF_VARS_EXAMPLE) $(TF_VARS); \
			echo "✅ Created $(TF_VARS)"; \
			echo "⚠️  Please edit $(TF_VARS) and configure your secrets (especially openai_api_key)"; \
		else \
			echo "❌ Error: $(TF_VARS_EXAMPLE) not found. Cannot create $(TF_VARS)"; \
			exit 1; \
		fi; \
	else \
		echo "✅ $(TF_VARS) exists"; \
	fi
	@echo ""
	@# Start Docker registry (image registry)
	@echo "Starting Docker registry (image registry)..."
	@if docker ps --format '{{.Names}}' | grep -q "^docker-registry$$"; then \
		echo "✅ Docker registry is already running"; \
	else \
		if docker ps -a --format '{{.Names}}' | grep -q "^docker-registry$$"; then \
			echo "Starting existing Docker registry container..."; \
			docker start docker-registry >/dev/null 2>&1 || true; \
		else \
			echo "Starting Docker registry via docker-compose..."; \
			if command -v docker-compose >/dev/null 2>&1; then \
				docker-compose -f docker-compose.registry.yml up -d; \
			else \
				docker compose -f docker-compose.registry.yml up -d; \
			fi; \
		fi; \
		echo "Waiting for Docker registry to be ready..."; \
		timeout=30; \
		while [ $$timeout -gt 0 ]; do \
			if curl -s http://localhost:5555/v2/ >/dev/null 2>&1; then \
				echo "✅ Docker registry is ready"; \
				break; \
			fi; \
			sleep 1; \
			timeout=$$((timeout - 1)); \
		done; \
		if [ $$timeout -eq 0 ]; then \
			echo "⚠️  Warning: Docker registry may not be fully ready. Check with: docker logs docker-registry"; \
		fi; \
	fi
	@echo ""
	@# Start Kind cluster
	@echo "Starting Kind cluster..."
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "✅ Kind cluster '$(CLUSTER_NAME)' already exists"; \
	else \
		echo "Creating Kind cluster '$(CLUSTER_NAME)' via Terraform..."; \
		cd $(TF_ENV_DIR) && terraform init >/dev/null 2>&1 || true; \
		if ! cd $(TF_ENV_DIR) && terraform apply -var-file=terraform.tfvars -target=kind_cluster.this -auto-approve 2>/dev/null; then \
			echo "⚠️  Warning: Failed to create cluster via Terraform. Trying direct kind create..."; \
			echo "kind: Cluster" > /tmp/kind-config.yaml; \
			echo "apiVersion: kind.x-k8s.io/v1alpha4" >> /tmp/kind-config.yaml; \
			echo "nodes:" >> /tmp/kind-config.yaml; \
			echo "- role: control-plane" >> /tmp/kind-config.yaml; \
			echo "  kubeadmConfigPatches:" >> /tmp/kind-config.yaml; \
			echo "  - |" >> /tmp/kind-config.yaml; \
			echo "    kind: InitConfiguration" >> /tmp/kind-config.yaml; \
			echo "    nodeRegistration:" >> /tmp/kind-config.yaml; \
			echo "      kubeletExtraArgs:" >> /tmp/kind-config.yaml; \
			echo "        node-labels: \"ingress-ready=true\"" >> /tmp/kind-config.yaml; \
			echo "  extraPortMappings:" >> /tmp/kind-config.yaml; \
			echo "  - containerPort: 80" >> /tmp/kind-config.yaml; \
			echo "    hostPort: 80" >> /tmp/kind-config.yaml; \
			echo "    protocol: TCP" >> /tmp/kind-config.yaml; \
			echo "  - containerPort: 443" >> /tmp/kind-config.yaml; \
			echo "    hostPort: 443" >> /tmp/kind-config.yaml; \
			echo "    protocol: TCP" >> /tmp/kind-config.yaml; \
			echo "- role: worker" >> /tmp/kind-config.yaml; \
			echo "- role: worker" >> /tmp/kind-config.yaml; \
			kind create cluster --name $(CLUSTER_NAME) --config /tmp/kind-config.yaml 2>/dev/null || true; \
			rm -f /tmp/kind-config.yaml; \
		fi; \
	fi
	@# Always set up kubeconfig (whether cluster was just created or already existed)
	@$(MAKE) setup-kubeconfig
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "✅ Kind cluster is ready"; \
	fi
	@echo ""
	@echo "=== Initialization Complete ==="
	@echo ""
	@echo "✅ Kind cluster: $(CLUSTER_NAME)"
	@echo "✅ Docker registry: http://localhost:5555"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit $(TF_VARS) and configure your secrets (if not already done)"
	@echo "  2. Run 'make infra-apply' to deploy infrastructure"
	@echo "  3. Run 'make all' for full workflow (build + deploy)"

# Helper to ensure Kind cluster exists (via Terraform)
ensure-cluster:
	@if ! kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "Cluster $(CLUSTER_NAME) not found. Creating via Terraform..."; \
		if [ ! -f $(TF_VARS) ]; then \
			echo "Error: $(TF_VARS) not found. Run 'make infra-apply' first."; \
			exit 1; \
		fi; \
		cd $(TF_ENV_DIR) && terraform apply -var-file=terraform.tfvars -target=kind_cluster.this -auto-approve || true; \
	fi

# Helper to set up kubeconfig
setup-kubeconfig: ensure-cluster
	@echo "Setting up kubeconfig for cluster '$(CLUSTER_NAME)'..."
	@# Check if context already exists in kubeconfig
	@if kubectl config get-contexts 2>/dev/null | grep -q "kind-$(CLUSTER_NAME)"; then \
		echo "✅ Context 'kind-$(CLUSTER_NAME)' already exists in kubeconfig"; \
		kubectl config use-context kind-$(CLUSTER_NAME) 2>/dev/null || true; \
	else \
		echo "Exporting kubeconfig from Kind cluster..."; \
		if kind export kubeconfig --name $(CLUSTER_NAME) 2>/dev/null; then \
			kubectl config use-context kind-$(CLUSTER_NAME) 2>/dev/null || true; \
			echo "✅ Kubeconfig exported and context set"; \
		else \
			echo "⚠️  Warning: Could not export kubeconfig. Cluster may not be ready yet."; \
		fi; \
	fi

# === INFRASTRUCTURE ===
infra-init: init
	@$(TF_SCRIPTS)/init.sh $(NAMESPACE)

infra-plan: infra-init
	@# Ensure kubeconfig is set up before running Terraform
	@$(MAKE) setup-kubeconfig
	@# Remove stale cluster state if cluster doesn't exist, then plan
	@if ! kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "Cluster not found, removing stale state if present..."; \
		cd $(TF_ENV_DIR) && terraform state rm kind_cluster.this 2>/dev/null || true; \
		echo "Planning without refresh (cluster will be created)..."; \
		cd $(TF_ENV_DIR) && terraform plan -var-file=terraform.tfvars -refresh=false; \
	else \
		$(TF_SCRIPTS)/plan.sh $(NAMESPACE); \
	fi

infra-apply: infra-init
	@if [ ! -f $(TF_VARS) ]; then \
		echo "Error: $(TF_VARS) not found. Copy terraform.tfvars.example to terraform.tfvars and configure it."; \
		exit 1; \
	fi
	@# Ensure kubeconfig is set up before running Terraform
	@$(MAKE) setup-kubeconfig
	@# Ensure cluster exists and is in Terraform state
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "Cluster exists, ensuring it's in Terraform state..."; \
		cd $(TF_ENV_DIR) && if ! terraform state show kind_cluster.this >/dev/null 2>&1; then \
			echo "Importing existing cluster into Terraform state..."; \
			terraform import -var-file=terraform.tfvars kind_cluster.this $(CLUSTER_NAME) 2>/dev/null || \
			echo "⚠️  Could not import cluster. Will create via Terraform if needed."; \
		fi; \
	else \
		echo "Cluster not found, removing stale Terraform state if present..."; \
		cd $(TF_ENV_DIR) && terraform state rm kind_cluster.this 2>/dev/null || true; \
	fi
	@# Remove stale observability module state if it exists (module was removed)
	@echo "Cleaning up stale observability state (if any)..."
	@if cd $(TF_ENV_DIR) && terraform state list 2>/dev/null | grep -q "^module.observability"; then \
		echo "Removing stale observability module from state..."; \
		cd $(TF_ENV_DIR) && terraform state list 2>/dev/null | grep "^module.observability" | while read resource; do \
			terraform state rm "$$resource" 2>/dev/null || true; \
		done; \
	fi
	@# Ensure cluster resource exists in state before refreshing (needed for provider config)
	@echo "Ensuring cluster is created/imported before applying other resources..."
	@cd $(TF_ENV_DIR) && terraform apply -var-file=terraform.tfvars -target=kind_cluster.this -auto-approve || true
	@# Refresh state and import existing resources if needed (handles partial runs)
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "Refreshing Terraform state to sync with existing resources..."; \
		cd $(TF_ENV_DIR) && terraform refresh -var-file=terraform.tfvars || true; \
		echo "Importing existing resources if not in state..."; \
		($(MAKE) setup-kubeconfig && \
		cd $(TF_ENV_DIR) && \
		if kubectl get namespace $(NAMESPACE) &>/dev/null && ! terraform state show module.namespace.kubernetes_namespace.this &>/dev/null 2>&1; then \
			echo "Importing namespace $(NAMESPACE)..."; \
			terraform import -var-file=terraform.tfvars module.namespace.kubernetes_namespace.this $(NAMESPACE) || true; \
		fi && \
		SERVER_VERSION=$$(grep '^server_version' $(TF_VARS) 2>/dev/null | cut -d'"' -f2 || echo 'latest') && \
		MIGRATION_JOB_NAME=server-migration-$$(echo $$SERVER_VERSION | tr '.' '-') && \
		if kubectl get job $$MIGRATION_JOB_NAME -n $(NAMESPACE) &>/dev/null && ! terraform state show module.server_migration.kubernetes_job.this &>/dev/null 2>&1; then \
			echo "Importing migration job $$MIGRATION_JOB_NAME..."; \
			terraform import -var-file=terraform.tfvars module.server_migration.kubernetes_job.this $(NAMESPACE)/$$MIGRATION_JOB_NAME || true; \
		fi && \
		if kubectl get deployment resume-agent -n $(NAMESPACE) &>/dev/null && ! terraform state show module.resume_agent.kubernetes_deployment.this &>/dev/null 2>&1; then \
			echo "Importing resume-agent deployment..."; \
			terraform import -var-file=terraform.tfvars module.resume_agent.kubernetes_deployment.this $(NAMESPACE)/resume-agent || true; \
		fi && \
		if kubectl get deployment web -n $(NAMESPACE) &>/dev/null && ! terraform state show module.web.kubernetes_deployment.this &>/dev/null 2>&1; then \
			echo "Importing web deployment..."; \
			terraform import -var-file=terraform.tfvars module.web.kubernetes_deployment.this $(NAMESPACE)/web || true; \
		fi && \
		if kubectl get deployment server -n $(NAMESPACE) &>/dev/null && ! terraform state show module.server.kubernetes_deployment.this &>/dev/null 2>&1; then \
			echo "Importing server deployment..."; \
			terraform import -var-file=terraform.tfvars module.server.kubernetes_deployment.this $(NAMESPACE)/server || true; \
		fi) || true; \
	fi
	@# Ensure database is deployed first
	@echo "Deploying infrastructure (cluster, database, ingress)..."
	@cd $(TF_ENV_DIR) && terraform apply -var-file=terraform.tfvars \
		-target=kind_cluster.this \
		-target=module.postgresql \
		-target=module.namespace \
		-target=null_resource.wait_for_ingress \
		-auto-approve || true
	@# Apply everything else (refresh will have synced existing resources)
	@$(TF_SCRIPTS)/apply.sh $(NAMESPACE) true

infra-destroy: infra-init
	@$(TF_SCRIPTS)/destroy.sh $(NAMESPACE) true

# === BUILDS ===
build-migration:
	cd typescript && docker build -f apps/server/Dockerfile.migration -t server-migration:latest .

build-all:
	@echo "Building all service images..."
	$(MAKE) -C python/resume-agent build
	$(MAKE) -C typescript build-server
	$(MAKE) -C typescript build-web
	$(MAKE) build-migration
	@echo "✅ All images built"
	@echo "Pushing images to Docker registry..."
	@# Verify Docker registry is accessible
	@if ! curl -f http://localhost:5555/v2/ >/dev/null 2>&1; then \
		echo "⚠️  Warning: Docker registry not accessible at http://localhost:5555"; \
		echo "   Start it with: docker-compose -f docker-compose.registry.yml up -d"; \
		echo "   Continuing anyway..."; \
	fi
	@# Get registry URL from Terraform output (defaults to localhost:5555)
	@cd $(TF_ENV_DIR) && terraform init >/dev/null 2>&1 || true
	@bash -c ' \
	REGISTRY_URL=$$(cd $(TF_ENV_DIR) && terraform output -no-color -raw registry_url 2>/dev/null | grep -v "Warning" | grep -v "No outputs" | grep -v "state file" | grep -v "empty" | head -1); \
	if [ -z "$$REGISTRY_URL" ] || ! echo "$$REGISTRY_URL" | grep -q ":"; then REGISTRY_URL="localhost:5555"; fi; \
	REPO_PREFIX="$(CLUSTER_NAME)-$(NAMESPACE)"; \
	echo "Using registry: $${REGISTRY_URL}"; \
	echo "Repository prefix: $${REPO_PREFIX}"; \
	echo "Tagging and pushing resume-agent:latest..."; \
	docker tag resume-agent:latest "$${REGISTRY_URL}/$${REPO_PREFIX}/resume-agent:latest" && \
	docker push "$${REGISTRY_URL}/$${REPO_PREFIX}/resume-agent:latest" && \
	echo "  ✅ Pushed resume-agent:latest" || echo "  ⚠️  Failed to push resume-agent"; \
	echo "Tagging and pushing server:latest..."; \
	docker tag server:latest "$${REGISTRY_URL}/$${REPO_PREFIX}/server:latest" && \
	docker push "$${REGISTRY_URL}/$${REPO_PREFIX}/server:latest" && \
	echo "  ✅ Pushed server:latest" || echo "  ⚠️  Failed to push server"; \
	echo "Tagging and pushing web:latest..."; \
	docker tag web:latest "$${REGISTRY_URL}/$${REPO_PREFIX}/web:latest" && \
	docker push "$${REGISTRY_URL}/$${REPO_PREFIX}/web:latest" && \
	echo "  ✅ Pushed web:latest" || echo "  ⚠️  Failed to push web"; \
	echo "Tagging and pushing server-migration:latest..."; \
	docker tag server-migration:latest "$${REGISTRY_URL}/$${REPO_PREFIX}/server-migration:latest" && \
	docker push "$${REGISTRY_URL}/$${REPO_PREFIX}/server-migration:latest" && \
	echo "  ✅ Pushed server-migration:latest" || echo "  ⚠️  Failed to push server-migration"; \
	echo "✅ Build and push complete"'

# === LOAD IMAGES ===
load-migration: build-migration
	kind load docker-image server-migration:latest --name $(CLUSTER_NAME)

load-all:
	$(MAKE) -C python/resume-agent load
	$(MAKE) -C typescript load-server
	$(MAKE) -C typescript load-web
	$(MAKE) load-migration

# === DEPLOY ===
deploy-all: infra-init load-all
	@$(TF_SCRIPTS)/apply.sh $(NAMESPACE) true
	@echo "Note: If secrets were updated, restart affected deployments with: make restart DEPLOYMENT=<name>"

# === FULL WORKFLOW ===
# Order: ensure cluster -> build images -> load images -> apply infra (includes services) -> health checks
all: ensure-cluster build-all load-all infra-apply check-migration check-db

check-migration: setup-kubeconfig
	@echo "Checking migration job status..."
	@SERVER_VERSION=$$(grep '^server_version' $(TF_VARS) 2>/dev/null | cut -d'"' -f2 || echo 'latest') && \
		MIGRATION_JOB_NAME=server-migration-$$(echo $$SERVER_VERSION | tr '.' '-') && \
		if kubectl get job $$MIGRATION_JOB_NAME -n $(NAMESPACE) &>/dev/null; then \
			echo "Waiting for migration job to complete..."; \
			kubectl wait --for=condition=complete job/$$MIGRATION_JOB_NAME -n $(NAMESPACE) --timeout=120s || \
				(kubectl logs job/$$MIGRATION_JOB_NAME -n $(NAMESPACE) --tail=20 && exit 1); \
		else \
			echo "Warning: Migration job not found. It will be created during deployment."; \
		fi

check-db: setup-kubeconfig
	@echo "Checking database status..."
	@kubectl wait --for=condition=ready pod -l app=postgresql -n database --timeout=120s || \
		echo "Warning: Database pods may not be ready yet. Check with: kubectl get pods -n database"

# === CLEANUP ===
clean:
	@echo "Cleaning up infrastructure..."
	@if [ -f $(TF_VARS) ]; then \
		echo "Destroying Terraform resources..."; \
		cd $(TF_ENV_DIR) && terraform destroy -var-file=terraform.tfvars -auto-approve -refresh=false || true; \
	fi
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "Deleting Kind cluster..."; \
		kind delete cluster --name $(CLUSTER_NAME) || true; \
	else \
		echo "Cluster not found."; \
	fi
	@echo "Cleanup complete!"

# === UTILITIES ===
status: setup-kubeconfig
	@echo "=== Pods in $(NAMESPACE) ==="
	@kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "=== Ingress ==="
	@kubectl get ingress -n $(NAMESPACE)

restart: setup-kubeconfig
	@if [ -z "$(DEPLOYMENT)" ]; then \
		echo "Error: DEPLOYMENT is required. Usage: make restart DEPLOYMENT=server"; \
		exit 1; \
	fi
	@echo "Restarting deployment $(DEPLOYMENT) to pick up new images..."
	@# Force pod recreation by updating an annotation (triggers rollout)
	@# This ensures pods are recreated and will use the newly loaded image in Kind
	@kubectl annotate deployment $(DEPLOYMENT) -n $(NAMESPACE) \
		restarted-at="$$(date +%s)" --overwrite || true
	@echo "Waiting for rollout to complete..."
	@kubectl rollout status deployment/$(DEPLOYMENT) -n $(NAMESPACE) --timeout=120s
	@echo "Deployment $(DEPLOYMENT) restarted successfully"

help:
	@echo "Usage: make [target] [NAMESPACE=staging]"
	@echo ""
	@echo "Initialization:"
	@echo "  init            Initialize development environment (tools, /etc/hosts, config)"
	@echo ""
	@echo "Infrastructure:"
	@echo "  infra-init      Initialize Terraform (runs init automatically)"
	@echo "  infra-plan      Plan infrastructure changes"
	@echo "  infra-apply     Apply infrastructure"
	@echo "  infra-destroy   Destroy infrastructure"
	@echo ""
	@echo "Build & Deploy:"
	@echo "  build-all       Build all service images"
	@echo "  load-all        Load images into Kind cluster"
	@echo "  deploy-all      Deploy all services"
	@echo ""
	@echo "Full Workflow:"
	@echo "  all             Deploy everything (infra + build + deploy)"
	@echo "  clean           Destroy cluster and infrastructure"
	@echo ""
	@echo "Utilities:"
	@echo "  ensure-cluster  Ensure Kind cluster exists (creates via Terraform if needed)"
	@echo "  status          Show cluster status"
	@echo "  restart         Restart a deployment (usage: make restart DEPLOYMENT=server)"
	@echo "  help            Show this help message"
