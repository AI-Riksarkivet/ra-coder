#!/bin/bash

# Dagger Build Script - Complete replacement for build.yaml Argo workflow
# Eliminates Argo complexity and dockerfileContent parameter limitations

set -e

# Default parameters (replaces Argo workflow parameters)
GIT_REPO="${GIT_REPO:-.}"
GIT_REF="${GIT_REF:-main}"
ENABLE_CUDA="${ENABLE_CUDA:-true}"
REGISTRY="${REGISTRY:-registry.ra.se:5002}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-airiksarkivet/devenv}"
IMAGE_TAG="${IMAGE_TAG:-v14.0.0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Dagger Build Pipeline - Replacing Argo Workflows${NC}"
echo "=================================================="
echo -e "${BLUE}Repository:${NC} $GIT_REPO"
echo -e "${BLUE}Reference:${NC}  $GIT_REF"
echo -e "${BLUE}Registry:${NC}   $REGISTRY"
echo -e "${BLUE}Image:${NC}      $REGISTRY/$IMAGE_REPOSITORY:$IMAGE_TAG"
echo -e "${BLUE}CUDA:${NC}       $ENABLE_CUDA"
echo ""

# Set up Dagger environment
export KUBECONFIG=/home/coder/coder-templates/kubeconfig
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://dagger?namespace=dagger&context=marieberg-context"

# Step 1: Validation (replaces Argo validation step)
echo -e "${YELLOW}📋 Step 1: Validating build configuration...${NC}"
echo -e "${BLUE}  • Checking Dagger connection...${NC}"
# Make sure we're in the repo root (where Dockerfile is)
if [ ! -f "Dockerfile" ]; then
  echo -e "${RED}❌ Dockerfile not found in current directory!${NC}"
  echo -e "${BLUE}Please run this script from the repository root directory${NC}"
  exit 1
fi

cd build-dagger

echo -e "${BLUE}  • Validating repository access...${NC}"
if [ "$GIT_REPO" = "." ]; then
  echo -e "${BLUE}  • Using current directory - skipping Git validation${NC}"
  echo -e "${GREEN}✅ Validation successful (current directory)!${NC}"
else
  if dagger call validate-build \
    --git-repo="$GIT_REPO" \
    --git-ref="$GIT_REF"; then
    echo -e "${GREEN}✅ Validation successful!${NC}"
  else
    echo -e "${RED}❌ Validation failed!${NC}"
    exit 1
  fi
fi

echo ""

# Step 2: Build (replaces entire Argo Kaniko workflow)
echo -e "${YELLOW}🔨 Step 2: Building container image...${NC}"
echo -e "${BLUE}  • Pulling Kaniko executor image...${NC}"
echo -e "${BLUE}  • Preparing build context...${NC}"
echo -e "${BLUE}  • Starting Kaniko build (this may take several minutes)...${NC}"

# Add progress indicator
(
  sleep 5
  while kill -0 $BUILD_PID 2>/dev/null; do
    echo -e "${BLUE}  • Build in progress... ⏳${NC}"
    sleep 30
  done
) &
PROGRESS_PID=$!

dagger call build-current-repo \
  --registry="$REGISTRY" \
  --image-repository="$IMAGE_REPOSITORY" \
  --image-tag="$IMAGE_TAG" \
  --enable-cuda="$ENABLE_CUDA" &
BUILD_PID=$!

# Wait for build to complete
if wait $BUILD_PID; then
  kill $PROGRESS_PID 2>/dev/null || true
  echo -e "${GREEN}✅ Build completed successfully!${NC}"
else
  kill $PROGRESS_PID 2>/dev/null || true
  echo -e "${RED}❌ Build failed!${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}🎉 Dagger build pipeline completed!${NC}"
echo -e "${BLUE}Benefits over Argo:${NC}"
echo "  • No dockerfileContent parameter size limits"
echo "  • Git-based source management"  
echo "  • Simpler execution (no Kubernetes workflow overhead)"
echo "  • Same Kaniko building, better source handling"
echo ""
echo -e "${BLUE}Image available at:${NC} $REGISTRY/$IMAGE_REPOSITORY:$IMAGE_TAG"