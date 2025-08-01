#!/bin/bash

# Dagger-based build script to replace the old Argo Workflow build.sh
# This uses Dagger with Kaniko directly, no Argo required

# Parameters: ENABLE_CUDA, SERVICE_NAME, TAG, REGISTRY
ENABLE_CUDA=${1:-${ENABLE_CUDA:-true}}
SERVICE_NAME=${2:-${SERVICE_NAME:-devenv}}
TAG=${3:-${TAG:-v14.0.0}}
REGISTRY=${4:-${REGISTRY:-registry.ra.se:5002}}

echo "Building with Dagger + Kaniko (no Argo)"
echo "CUDA support: $ENABLE_CUDA"
echo "Service: $SERVICE_NAME"  
echo "Tag: $TAG"
echo "Registry: $REGISTRY"

# Read Dockerfile content
if [ ! -f "Dockerfile" ]; then
    echo "Error: Dockerfile not found in current directory"
    exit 1
fi

DOCKERFILE_CONTENT=$(cat Dockerfile)

# Execute Dagger build with Kaniko
echo "Executing Dagger build..."
dagger call build-image \
    --dockerfile-content="$DOCKERFILE_CONTENT" \
    --enable-cuda="$ENABLE_CUDA" \
    --registry="$REGISTRY" \
    --image-repository="airiksarkivet/$SERVICE_NAME" \
    --image-tag="$TAG" \
    --service-name="$SERVICE_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo "Image: $REGISTRY/airiksarkivet/$SERVICE_NAME:$TAG$([ "$ENABLE_CUDA" = "false" ] && echo "-cpu")"
else
    echo "❌ Build failed!"
    exit 1
fi