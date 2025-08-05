SERVICE ?= devenv
TAG ?= v14.1.3
REGISTRY ?= registry.ra.se:5002
IMAGE_NAME = airiksarkivet/$(SERVICE)
ENABLE_CUDA ?= true

# Dagger build targets (local builds only)
dagger-build-local:
	@echo "Building image locally with Dagger (CUDA=$(ENABLE_CUDA))..."
	@cd .. && dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=$(ENABLE_CUDA) --image-tag=$(TAG)

dagger-build-cuda:
	@echo "Building CUDA image locally with Dagger..."
	@cd .. && dagger call quick-cuda-build --source="./Riksarkivets-Development-Template"

dagger-build-cpu:
	@echo "Building CPU image locally with Dagger..."
	@cd .. && dagger call quick-cpu-build --source="./Riksarkivets-Development-Template"

# Dagger build and publish targets (requires authentication)
dagger-publish:
	@echo "Building and publishing image with Dagger (CUDA=$(ENABLE_CUDA))..."
	@echo "Note: You need to provide --username and --password parameters"
	@cd .. && dagger call build-and-publish --source="./Riksarkivets-Development-Template" --enable-cuda=$(ENABLE_CUDA) --image-tag=$(TAG)

# Legacy Docker build targets (for compatibility)
docker-build:
	@docker build -t $(IMAGE_NAME):$(TAG) .

docker-tag:
	@docker tag $(IMAGE_NAME):$(TAG) $(REGISTRY)/$(IMAGE_NAME):$(TAG)

docker-push:
	@docker push $(REGISTRY)/$(IMAGE_NAME):$(TAG)

docker-release: docker-build docker-tag docker-push
	@echo "Docker image built, tagged, and pushed successfully!"

# Main build targets
build: dagger-build-local
	@echo "Image built successfully with Dagger!"

build-cuda: dagger-build-cuda
	@echo "CUDA image built successfully with Dagger!"

build-cpu: dagger-build-cpu
	@echo "CPU image built successfully with Dagger!"

# Help target
help:
	@echo "Available targets:"
	@echo "  build           - Build image locally with Dagger (respects ENABLE_CUDA)"
	@echo "  build-cuda      - Build CUDA image locally with Dagger"
	@echo "  build-cpu       - Build CPU image locally with Dagger"
	@echo "  dagger-publish  - Build and publish to registry (needs auth)"
	@echo "  docker-*        - Legacy Docker build targets"
	@echo ""
	@echo "Variables:"
	@echo "  ENABLE_CUDA=$(ENABLE_CUDA)  - Enable CUDA support"
	@echo "  TAG=$(TAG)             - Image tag"
	@echo "  SERVICE=$(SERVICE)         - Service name"
	@echo "  REGISTRY=$(REGISTRY)  - Registry URL"
