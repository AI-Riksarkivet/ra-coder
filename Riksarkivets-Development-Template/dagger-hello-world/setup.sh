#!/bin/bash

# Dagger Hello World - Kubernetes Engine Setup
# This script sets up connection to a Dagger engine running in Kubernetes

set -e

echo "🚀 Setting up Dagger connection to Kubernetes engine..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not available. Please install kubectl first."
    exit 1
fi

# Check if dagger namespace exists
if ! kubectl get namespace dagger &> /dev/null; then
    echo "⚠️  Dagger namespace doesn't exist. Installing Dagger engine..."
    
    # Install Dagger engine via Helm
    if ! command -v helm &> /dev/null; then
        echo "❌ helm is not available. Please install helm first."
        echo "   Or ask your cluster admin to deploy Dagger engine."
        exit 1
    fi
    
    helm upgrade --install --namespace=dagger --create-namespace \
      dagger oci://registry.dagger.io/dagger-helm
    
    echo "⏳ Waiting for Dagger engine to be ready..."
    kubectl wait --for=condition=ready pod --selector=name=dagger-dagger-helm-engine -n dagger --timeout=300s
fi

# Get Dagger engine pod name
DAGGER_ENGINE_POD_NAME="$(kubectl get pod \
  --selector=name=dagger-dagger-helm-engine --namespace=dagger \
  --output=jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

if [ -z "$DAGGER_ENGINE_POD_NAME" ]; then
    echo "❌ No Dagger engine pod found. Please check your Kubernetes cluster."
    echo "   Run: kubectl get pods -n dagger"
    exit 1
fi

echo "✅ Found Dagger engine pod: $DAGGER_ENGINE_POD_NAME"

# Set environment variable for Dagger connection
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://$DAGGER_ENGINE_POD_NAME?namespace=dagger"

echo "🔗 Setting Dagger connection to Kubernetes engine:"
echo "   _EXPERIMENTAL_DAGGER_RUNNER_HOST=$_EXPERIMENTAL_DAGGER_RUNNER_HOST"

# Save to .env file for future use
cat > .env << EOF
# Dagger Kubernetes Engine Connection
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://$DAGGER_ENGINE_POD_NAME?namespace=dagger"
EOF

echo "💾 Connection saved to .env file"
echo ""
echo "🎯 To use this connection in future terminal sessions:"
echo "   source ./setup.sh"
echo "   # or"
echo "   source .env"
echo ""
echo "✨ Testing connection..."

# Test the connection
if dagger version; then
    echo "✅ Successfully connected to Dagger engine in Kubernetes!"
    echo ""
    echo "🚀 Ready to run Dagger examples:"
    echo "   dagger call hello"
    echo "   dagger call container-hello"
    echo "   dagger call build-example --source=git://github.com/example/repo"
else
    echo "❌ Failed to connect to Dagger engine"
    exit 1
fi