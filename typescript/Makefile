CLUSTER_NAME ?= devops-demo
SERVER_TAG ?= latest
WEB_TAG ?= latest

.PHONY: build-server build-web build-all load-server load-web load-all test dev

# Build
build-server:
	docker build -t server:$(SERVER_TAG) -f apps/server/Dockerfile .

build-web:
	docker build -t web:$(WEB_TAG) -f apps/web/Dockerfile \
		--build-arg VITE_SERVER_URL=http://localhost/api .

build-all: build-server build-web

# Load into Kind
load-server: build-server
	kind load docker-image server:$(SERVER_TAG) --name $(CLUSTER_NAME)

load-web: build-web
	kind load docker-image web:$(WEB_TAG) --name $(CLUSTER_NAME)

load-all: load-server load-web

# Test
test:
	curl -s http://localhost/api/
	curl -s http://localhost/

# Dev
dev:
	pnpm dev
