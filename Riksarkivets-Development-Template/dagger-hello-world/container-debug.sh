#!/bin/bash

# Container Debug Script - Focus on container operations
# Isolates the container operation issue

set -e

echo "🐳 Container Operation Debug"
echo "=========================="

source .env

echo "🔗 Connected to: $(./quick-node-switch.sh current | grep 'Running on node' | cut -d':' -f2 | xargs)"
echo ""

# Enable maximum debugging
export DAGGER_LOG_LEVEL=trace
export DAGGER_PROGRESS=plain

echo "🧪 Test 1: Basic version (should work quickly)"
echo "---------------------------------------------"
time dagger version
echo ""

echo "🧪 Test 2: Container operation with trace logging"
echo "------------------------------------------------"
echo "Command: dagger --debug --progress=plain call container --from alpine:latest"
echo "Starting at: $(date)"
echo ""

# Start container operation with detailed logging and timeout
timeout 90 dagger --debug --progress=plain call container --from alpine:latest 2>&1 | while IFS= read -r line; do
    echo "[$(date '+%H:%M:%S')] $line"
done || {
    exit_code=$?
    echo ""
    echo "[$(date '+%H:%M:%S')] ❌ Container operation failed/timed out with exit code: $exit_code"
    
    # Check engine logs during the failure
    echo ""
    echo "🔍 Engine logs during failure:"
    pod_name=$(echo "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" | sed 's/kube-pod:\/\/\([^?]*\).*/\1/')
    kubectl logs "$pod_name" -n dagger --tail=10 | sed 's/^/   /'
}

echo ""
echo "📊 Debug complete at: $(date)"