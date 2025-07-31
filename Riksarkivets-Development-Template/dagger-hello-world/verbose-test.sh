#!/bin/bash

# Verbose Test Script - Step-by-step debugging
# Shows exactly what happens at each stage

set -e

echo "🔍 Verbose Dagger Test - Step by Step"
echo "====================================="

# Step 1: Connection check
echo "📡 Step 1: Checking connection..."
source .env
echo "   Connection string: $_EXPERIMENTAL_DAGGER_RUNNER_HOST"

# Step 2: Pod health check
echo ""
echo "🏥 Step 2: Checking pod health..."
pod_name=$(echo "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" | sed 's/kube-pod:\/\/\([^?]*\).*/\1/')
node_name=$(kubectl get pod "$pod_name" -n dagger -o jsonpath='{.spec.nodeName}' 2>/dev/null)
pod_status=$(kubectl get pod "$pod_name" -n dagger -o jsonpath='{.status.phase}' 2>/dev/null)
echo "   Pod: $pod_name"
echo "   Node: $node_name" 
echo "   Status: $pod_status"

# Step 3: Engine logs check
echo ""
echo "📋 Step 3: Recent engine logs (last 5 lines)..."
kubectl logs "$pod_name" -n dagger --tail=5 | sed 's/^/   /'

# Step 4: Basic dagger version with timing
echo ""
echo "⏱️  Step 4: Testing basic connection (30s timeout)..."
echo "   Command: dagger version"
echo "   Start time: $(date)"

# Use script to capture timing
(
  timeout 30 dagger version 2>&1 | while IFS= read -r line; do
    echo "   [$(date '+%H:%M:%S')] $line"
  done
) || echo "   [$(date '+%H:%M:%S')] ❌ Command timed out or failed"

# Step 5: Simple container test with verbose output
echo ""
echo "🐳 Step 5: Testing container operation with verbose output..."
echo "   Command: dagger --verbose call container --from alpine:latest"
echo "   Start time: $(date)"

export DAGGER_LOG_LEVEL=debug

(
  timeout 60 dagger --verbose call container --from alpine:latest 2>&1 | while IFS= read -r line; do
    echo "   [$(date '+%H:%M:%S')] $line"
  done
) || echo "   [$(date '+%H:%M:%S')] ❌ Container test timed out or failed"

echo ""
echo "🔍 Step 6: Connection diagnostics..."
echo "   Checking if we can reach the pod directly..."

# Try to get pod IP and test connectivity
pod_ip=$(kubectl get pod "$pod_name" -n dagger -o jsonpath='{.status.podIP}' 2>/dev/null)
echo "   Pod IP: $pod_ip"

if [ -n "$pod_ip" ]; then
    echo "   Testing pod connectivity..."
    timeout 5 nc -zv "$pod_ip" 8080 2>&1 | sed 's/^/   /' || echo "   Cannot connect to pod on port 8080"
fi

echo ""
echo "📊 Summary:"
echo "   Pod: $pod_name ($pod_status)"
echo "   Node: $node_name"
echo "   Connection: $_EXPERIMENTAL_DAGGER_RUNNER_HOST"
echo "   Time: $(date)"