SERVICE ?= devenv
TAG ?= v13.4.0
REGISTRY ?= registry.ra.se:5002
IMAGE_NAME = airiksarkivet/$(SERVICE)
ENABLE_CUDA ?= true
NAMESPACE ?= ci

docker-build:
	@docker build -t $(IMAGE_NAME):$(TAG) .

docker-tag:
	@docker tag $(IMAGE_NAME):$(TAG) $(REGISTRY)/$(IMAGE_NAME):$(TAG)

docker-push:
	@docker push $(REGISTRY)/$(IMAGE_NAME):$(TAG)

docker-release: docker-build docker-tag docker-push
	@echo "Docker image built, tagged, and pushed successfully!"

# Kaniko build targets
kaniko-build-cuda:
	@echo "Building CUDA image with Kaniko via Argo..."
	@./build.sh true $(SERVICE) $(TAG) $(REGISTRY)

kaniko-build-cpu:
	@echo "Building CPU image with Kaniko via Argo..."
	@./build.sh false $(SERVICE) $(TAG) $(REGISTRY)

kaniko-build:
	@echo "Building image with Kaniko via Argo (CUDA=$(ENABLE_CUDA))..."
	@./build.sh $(ENABLE_CUDA) $(SERVICE) $(TAG) $(REGISTRY)

# Combined release targets
release-cuda: kaniko-build-cuda
	@echo "CUDA image built and pushed via Kaniko successfully!"

release-cpu: kaniko-build-cpu
	@echo "CPU image built and pushed via Kaniko successfully!"

release: kaniko-build
	@echo "Image built and pushed via Kaniko successfully!"

dev:
	uv sync
	docker compose up --build