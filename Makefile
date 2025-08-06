# Dagger Build Variables
# Note: build-both runs GPU and CPU builds in parallel for faster execution
USERNAME ?= airiksarkivet
PASSWORD ?= 
SOURCE ?= ./Riksarkivets-Development-Template
ENABLE_CUDA ?= true
IMAGE_TAG ?= v14.2.0
REGISTRY ?= docker.io
IMAGE_REPOSITORY ?= riksarkivet/coder-workspace-ml

# Default target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  test          - Build and publish with default settings"
	@echo "  build-gpu     - Build GPU-enabled image"
	@echo "  build-cpu     - Build CPU-only image"
	@echo "  build-both    - Build both GPU and CPU images (in parallel)"
	@echo "  build-both-parallel - Build both using make -j (alternative parallel method)"
	@echo ""
	@echo "Variables:"
	@echo "  USERNAME      = $(USERNAME)"
	@echo "  PASSWORD      = [hidden]"
	@echo "  SOURCE        = $(SOURCE)"
	@echo "  ENABLE_CUDA   = $(ENABLE_CUDA)"
	@echo "  IMAGE_TAG     = $(IMAGE_TAG)"
	@echo "  REGISTRY      = $(REGISTRY)"
	@echo "  IMAGE_REPOSITORY = $(IMAGE_REPOSITORY)"
	@echo ""
	@echo "Usage examples:"
	@echo "  make test PASSWORD=your_password"
	@echo "  make build-gpu IMAGE_TAG=v14.3.0 PASSWORD=your_password"
	@echo "  make build-both PASSWORD=your_password  # Builds GPU and CPU in parallel"
	@echo "  make -j2 build-both-parallel PASSWORD=your_password  # Alternative parallel method"

.PHONY: check-password
check-password:
	@if [ -z "$(PASSWORD)" ]; then \
		echo "Error: PASSWORD variable is required"; \
		echo "Usage: make test PASSWORD=your_password"; \
		exit 1; \
	fi

.PHONY: test
test: check-password
	dagger call build-and-publish \
		--username="$(USERNAME)" \
		--password="$(PASSWORD)" \
		--source="$(SOURCE)" \
		--enable-cuda="$(ENABLE_CUDA)" \
		--image-tag="$(IMAGE_TAG)" \
		--registry="$(REGISTRY)" \
		--image-repository="$(IMAGE_REPOSITORY)"

.PHONY: build-gpu
build-gpu: check-password
	@echo "[GPU BUILD] Starting GPU-enabled image build..."
	dagger call build-and-publish \
		--username="$(USERNAME)" \
		--password="$(PASSWORD)" \
		--source="$(SOURCE)" \
		--enable-cuda="true" \
		--image-tag="$(IMAGE_TAG)" \
		--registry="$(REGISTRY)" \
		--image-repository="$(IMAGE_REPOSITORY)"
	@echo "[GPU BUILD] Completed!"

.PHONY: build-cpu
build-cpu: check-password
	@echo "[CPU BUILD] Starting CPU-only image build..."
	dagger call build-and-publish \
		--username="$(USERNAME)" \
		--password="$(PASSWORD)" \
		--source="$(SOURCE)" \
		--enable-cuda="false" \
		--image-tag="$(IMAGE_TAG)-cpu" \
		--registry="$(REGISTRY)" \
		--image-repository="$(IMAGE_REPOSITORY)"
	@echo "[CPU BUILD] Completed!"

.PHONY: build-both
build-both: check-password
	@echo "Building GPU and CPU images in parallel..."
	@$(MAKE) build-gpu PASSWORD="$(PASSWORD)" & \
	$(MAKE) build-cpu PASSWORD="$(PASSWORD)" & \
	wait
	@echo "Both builds completed!"

.PHONY: build-both-parallel
build-both-parallel: build-gpu build-cpu

.PHONY: dry-run
dry-run:
	@echo "Would execute:"
	@echo "dagger call build-and-publish \\"
	@echo "  --username=\"$(USERNAME)\" \\"
	@echo "  --password=\"[hidden]\" \\"
	@echo "  --source=\"$(SOURCE)\" \\"
	@echo "  --enable-cuda=\"$(ENABLE_CUDA)\" \\"
	@echo "  --image-tag=\"$(IMAGE_TAG)\" \\"
	@echo "  --registry=\"$(REGISTRY)\" \\"
	@echo "  --image-repository=\"$(IMAGE_REPOSITORY)\""
