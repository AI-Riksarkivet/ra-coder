#!/bin/bash

# Debug Build Script - Shows detailed Dagger execution info
# This script adds comprehensive debugging to see what's happening during builds

set -e

echo "🔍 Dagger Debug Build Test"
echo "========================="

# Source connection
source .env

echo "🔗 Connection: $_EXPERIMENTAL_DAGGER_RUNNER_HOST"
echo ""

# Set debug environment variables
export DAGGER_LOG_LEVEL=debug
export DAGGER_LOG_FORMAT=pretty
export _EXPERIMENTAL_DAGGER_TRACE=1
export _EXPERIMENTAL_DAGGER_INTERACTIVE_TUI=1

echo "🐛 Debug settings enabled:"
echo "   DAGGER_LOG_LEVEL=debug"
echo "   DAGGER_LOG_FORMAT=pretty" 
echo "   _EXPERIMENTAL_DAGGER_TRACE=1"
echo "   _EXPERIMENTAL_DAGGER_INTERACTIVE_TUI=1"
echo ""

echo "🧪 Test 1: Basic version check with debug"
echo "----------------------------------------"
dagger version --debug

echo ""
echo "🧪 Test 2: Container operation with full debug output"
echo "----------------------------------------------------"
echo "Starting container build on node $(./quick-node-switch.sh current | grep 'Running on node' | cut -d':' -f2 | xargs)..."

# Run with maximum debugging
dagger --debug --progress=plain call container \
  --from=alpine:latest \
  --with-exec=echo,"Hello from debug build!" \
  stdout

echo ""
echo "✅ Debug build completed!"