SERVICE ?= devenv
TAG ?= v9.0.0
REGISTRY ?= registry.ra.se:5002
IMAGE_NAME = airiksarkivet/$(SERVICE)

docker-build:
	@docker build -t $(IMAGE_NAME):$(TAG) .

docker-tag:
	@docker tag $(IMAGE_NAME):$(TAG) $(REGISTRY)/$(IMAGE_NAME):$(TAG)

docker-push:
	@docker push $(REGISTRY)/$(IMAGE_NAME):$(TAG)

docker-release: docker-build docker-tag docker-push
	@echo "Docker image built, tagged, and pushed successfully!"

dev:
	uv sync
	docker compose up --build