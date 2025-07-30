#!/bin/bash

# Parameters: ENABLE_CUDA, SERVICE_NAME, TAG, REGISTRY, KUBECONFIG
ENABLE_CUDA=${1:-${ENABLE_CUDA:-true}}
SERVICE_NAME=${2:-${SERVICE_NAME:-devenv}}
TAG=${3:-${TAG:-v13.6.0}}
REGISTRY=${4:-${REGISTRY:-registry.ra.se:5002}}
CUSTOM_KUBECONFIG=${5:-${CUSTOM_KUBECONFIG:-}}

# Set kubeconfig option for argo commands
KUBECONFIG_OPTION=""
if [ -n "$CUSTOM_KUBECONFIG" ]; then
    echo "Using custom kubeconfig: $CUSTOM_KUBECONFIG"
    KUBECONFIG_OPTION="--kubeconfig $CUSTOM_KUBECONFIG"
fi

# Set repository and tag based on CUDA support
IMAGE_REPOSITORY="airiksarkivet/${SERVICE_NAME}"
if [ "$ENABLE_CUDA" = "true" ]; then
    IMAGE_TAG="${TAG}"
else
    IMAGE_TAG="${TAG}-cpu"
fi

IMAGE_NAME="${REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"

echo "Submitting workflow with CUDA support: $ENABLE_CUDA"
echo "Image name: $IMAGE_NAME"
TIMESTAMP=$(date +%s)
WORKFLOW_NAME=$(argo submit build.yaml $KUBECONFIG_OPTION --generate-name "kaniko-build-${SERVICE_NAME}-${TIMESTAMP}-" -p dockerfileContent="$(cat Dockerfile)" -p enableCuda="$ENABLE_CUDA" -p registry="$REGISTRY" -p imageRepository="$IMAGE_REPOSITORY" -p imageTag="$IMAGE_TAG" -n ci -o name)

if [ -z "$WORKFLOW_NAME" ]; then
  echo "Failed to submit workflow or capture its name."
  exit 1
fi

echo "Workflow submitted with: $WORKFLOW_NAME"

echo "Following logs for $WORKFLOW_NAME..."
argo logs $KUBECONFIG_OPTION --follow "$WORKFLOW_NAME" -n ci

echo "Workflow $WORKFLOW_NAME completed. Will be auto-deleted after 3 hours."
echo "To manually delete: argo delete $KUBECONFIG_OPTION $WORKFLOW_NAME -n ci"