.PHONY: all infra-init infra-plan infra-apply infra-destroy build-all load-all deploy-all clean status restart ensure-cluster setup-kubeconfig help

CLUSTER_NAME ?= devops-demo
NAMESPACE ?= production
TF_DIR := infra
TF_ENV_DIR := $(CURDIR)/$(TF_DIR)/envs/$(NAMESPACE)
TF_VARS := $(TF_ENV_DIR)/terraform.tfvars
TF_SCRIPTS := $(CURDIR)/$(TF_DIR)/scripts

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
	@kind export kubeconfig --name $(CLUSTER_NAME) 2>/dev/null && \
		kubectl config use-context kind-$(CLUSTER_NAME) 2>/dev/null || true

# === INFRASTRUCTURE ===
infra-init:
	@$(TF_SCRIPTS)/init.sh $(NAMESPACE)

infra-plan: infra-init
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
	@# Remove cluster from state if it doesn't exist (stale state)
	@if ! kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "Cluster not found, removing stale Terraform state..."; \
		cd $(TF_ENV_DIR) && terraform state rm kind_cluster.this 2>/dev/null || true; \
	fi
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
	@# Ensure database and observability are deployed first
	@echo "Deploying infrastructure (cluster, database, observability)..."
	@cd $(TF_ENV_DIR) && terraform apply -var-file=terraform.tfvars \
		-target=kind_cluster.this \
		-target=module.postgresql \
		-target=module.observability \
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
	$(MAKE) -C python/resume-agent build
	$(MAKE) -C typescript build-server
	$(MAKE) -C typescript build-web
	$(MAKE) build-migration

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
	@echo ""
	@echo "Grafana: http://localhost:30080 (admin/admin)"
	@echo "Note: Access Grafana via NodePort only (ingress removed to avoid redirect loops)"

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
	@echo "Restarting deployment $(DEPLOYMENT)..."
	@kubectl rollout restart deployment/$(DEPLOYMENT) -n $(NAMESPACE)
	@kubectl rollout status deployment/$(DEPLOYMENT) -n $(NAMESPACE) --timeout=120s

help:
	@echo "Usage: make [target] [NAMESPACE=staging]"
	@echo ""
	@echo "Infrastructure:"
	@echo "  infra-init      Initialize Terraform"
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
