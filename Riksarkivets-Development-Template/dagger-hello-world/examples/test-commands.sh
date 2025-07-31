#!/bin/bash

# Dagger Hello World - Test Commands
# Run these commands to test the hybrid Go + Python setup

set -e

echo "🚀 Dagger Hybrid Workflow Test Commands"
echo "========================================"

# Make sure we're connected to Kubernetes engine
if [ -z "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" ]; then
    echo "⚠️  Setting up Dagger connection..."
    source ../setup.sh
fi

echo ""
echo "🔧 Testing Go Infrastructure Module:"
echo "------------------------------------"

echo "🔧 Hello from Go module:"
dagger -m ../go-infrastructure call hello

echo ""
echo "🔧 Container info from Go module:"
dagger -m ../go-infrastructure call container-info

echo ""
echo "🔧 Infrastructure advantages:"
dagger -m ../go-infrastructure call infrastructure-advantages

echo ""
echo "🐍 Testing Python Data Module:"
echo "-------------------------------"

echo "🐍 Hello from Python module:"
dagger -m ../python-data call hello

echo ""
echo "🐍 Data processing example:"
dagger -m ../python-data call process-data --input-data="Hello world from Dagger hybrid setup" --operation="analyze"

echo ""
echo "🐍 ML Pipeline example:"
dagger -m ../python-data call ml-pipeline --data-source="demo dataset" --model-type="classification"

echo ""
echo "🐍 Python advantages:"
dagger -m ../python-data call python-advantages

echo ""
echo "🚀 Testing Hybrid Workflow:"
echo "---------------------------"

echo "🚀 Hello from hybrid workflow:"
dagger -m ../hybrid-workflow call hello

echo ""
echo "🚀 Environment info from both modules:"
dagger -m ../hybrid-workflow call environment-info

echo ""
echo "🚀 Hybrid advantages:"
dagger -m ../hybrid-workflow call hybrid-advantages

echo ""
echo "🎯 Complete pipeline example:"
dagger -m ../hybrid-workflow call complete-pipeline \
  --repo="https://github.com/docker/getting-started" \
  --training-data="production ML training data" \
  --registry="registry.ra.se:5002" \
  --repository="hybrid-demo" \
  --tag="v1.0"

echo ""
echo "✅ All tests completed successfully!"
echo "🎉 Hybrid Go + Python Dagger workflow is working!"