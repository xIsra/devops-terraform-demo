CLUSTER_NAME ?= devops-demo
SERVER_TAG ?= latest
WEB_TAG ?= latest

.PHONY: build-server build-web build-all load-server load-web load-all test dev

# Build
# Docker cache will automatically invalidate when source code changes
build-server:
	docker build -t server:$(SERVER_TAG) -f apps/server/Dockerfile .

build-web:
	@if [ -f apps/web/.env ]; then \
		export $$(grep -v '^#' apps/web/.env | xargs) && \
		docker build -t web:$(WEB_TAG) -f apps/web/Dockerfile \
			--build-arg VITE_SERVER_URL=$${VITE_SERVER_URL:-https://devops-demo.local/api} .; \
	else \
		docker build -t web:$(WEB_TAG) -f apps/web/Dockerfile \
			--build-arg VITE_SERVER_URL=https://devops-demo.local/api .; \
	fi

build-all: build-server build-web

# Load into Kind
# Note: kind load replaces existing images with the same tag
# After loading, restart deployments to pick up new images
load-server: build-server
	@echo "Loading server:$(SERVER_TAG) into Kind cluster $(CLUSTER_NAME)..."
	kind load docker-image server:$(SERVER_TAG) --name $(CLUSTER_NAME)

load-web: build-web
	@echo "Loading web:$(WEB_TAG) into Kind cluster $(CLUSTER_NAME)..."
	kind load docker-image web:$(WEB_TAG) --name $(CLUSTER_NAME)

load-all: load-server load-web

# Test
test:
	curl -s http://localhost/api/
	curl -s http://localhost/

# Dev
dev:
	pnpm dev
