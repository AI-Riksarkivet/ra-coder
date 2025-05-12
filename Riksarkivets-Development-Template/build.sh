#!/bin/bash

echo "Submitting workflow..."
WORKFLOW_NAME=$(argo submit build.yaml --generate-name "my-workflow-" -p dockerfileContent="$(cat Dockerfile)" -n ci -o name)

if [ -z "$WORKFLOW_NAME" ]; then
  echo "Failed to submit workflow or capture its name."
  exit 1
fi

echo "Workflow submitted with: $WORKFLOW_NAME"

echo "Following logs for $WORKFLOW_NAME..."
argo logs --follow "$WORKFLOW_NAME" -n ci