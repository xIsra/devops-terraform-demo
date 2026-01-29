IMAGE_NAME := resume-agent
IMAGE_TAG ?= latest
CLUSTER_NAME ?= devops-demo

.PHONY: build load test dev

# Build
# Docker cache will automatically invalidate when source code changes
build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

load: build
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) --name $(CLUSTER_NAME)

test:
	curl -s http://localhost/resume-api/api/v1/health

# Local dev
dev:
	uv run uvicorn resume_agent.main:app --reload
