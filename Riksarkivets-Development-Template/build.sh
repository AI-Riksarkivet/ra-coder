#!/bin/bash

# Default to CUDA enabled, but allow override with environment variable or parameter
ENABLE_CUDA=${1:-${ENABLE_CUDA:-true}}

# Default version, can be overridden with environment variable
VERSION=${VERSION:-v9.0.0}

# Set image name based on CUDA support
if [ "$ENABLE_CUDA" = "true" ]; then
    IMAGE_NAME="registry.ra.se:5002/airiksarkivet/devenv:${VERSION}"
else
    IMAGE_NAME="registry.ra.se:5002/airiksarkivet/devenv:${VERSION}-cpu"
fi

echo "Submitting workflow with CUDA support: $ENABLE_CUDA"
echo "Image name: $IMAGE_NAME"
WORKFLOW_NAME=$(argo submit build.yaml --generate-name "my-workflow-" -p dockerfileContent="$(cat Dockerfile)" -p enableCuda="$ENABLE_CUDA" -p imageName="$IMAGE_NAME" -n ci -o name)

if [ -z "$WORKFLOW_NAME" ]; then
  echo "Failed to submit workflow or capture its name."
  exit 1
fi

echo "Workflow submitted with: $WORKFLOW_NAME"

echo "Following logs for $WORKFLOW_NAME..."
argo logs --follow "$WORKFLOW_NAME" -n ci

echo "Deleting workflow $WORKFLOW_NAME..."
argo delete "$WORKFLOW_NAME" -n ci