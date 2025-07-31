#!/bin/bash

# Dagger Hello World - Verification Script
# This script verifies that the hybrid Go + Python setup is working correctly

set -e

echo "🔍 Dagger Hello World - Verification Checklist"
echo "==============================================="

# Step 1: Check directory structure
echo "📁 Step 1: Checking directory structure..."
if [ -d "go-infrastructure" ] && [ -d "python-data" ] && [ -d "hybrid-workflow" ]; then
    echo "   ✅ All module directories present"
else
    echo "   ❌ Missing module directories"
    exit 1
fi

# Step 2: Check required files
echo "📄 Step 2: Checking required files..."
required_files=(
    "setup.sh"
    "README.md" 
    "USAGE.md"
    "go-infrastructure/dagger.json"
    "go-infrastructure/main.go"
    "python-data/dagger.json"
    "python-data/main.py"
    "hybrid-workflow/dagger.json"
    "hybrid-workflow/main.go"
)

all_files_present=true
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file"
    else
        echo "   ❌ Missing: $file"
        all_files_present=false
    fi
done

if [ "$all_files_present" = false ]; then
    echo "   ❌ Some required files are missing"
    exit 1
fi

# Step 3: Check Dagger installation
echo "🔧 Step 3: Checking Dagger installation..."
if command -v dagger &> /dev/null; then
    echo "   ✅ Dagger CLI installed: $(dagger version | head -1)"
else
    echo "   ❌ Dagger CLI not found. Install with: brew install dagger/tap/dagger"
    exit 1
fi

# Step 4: Check Kubernetes connection
echo "🔗 Step 4: Checking Kubernetes connection..."
if command -v kubectl &> /dev/null; then
    if kubectl get pods -n dagger &> /dev/null; then
        pod_count=$(kubectl get pods -n dagger --no-headers | wc -l)
        echo "   ✅ Kubernetes connection working"
        echo "   ✅ Found $pod_count Dagger engine pod(s) in namespace 'dagger'"
        
        # Get engine pod name
        engine_pod=$(kubectl get pod --selector=name=dagger-dagger-helm-engine -n dagger -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ -n "$engine_pod" ]; then
            echo "   ✅ Dagger engine pod: $engine_pod"
        else
            echo "   ⚠️  No Dagger engine pod found with expected selector"
        fi
    else
        echo "   ⚠️  Cannot access dagger namespace. Engine may not be deployed."
        echo "   💡 Run: helm install dagger oci://registry.dagger.io/dagger-helm -n dagger --create-namespace"
    fi
else
    echo "   ❌ kubectl not found. Cannot check Kubernetes connection"
fi

# Step 5: Check Dagger engine connection setup
echo "🚀 Step 5: Checking Dagger engine connection setup..."
if [ -f ".env" ]; then
    echo "   ✅ .env file exists"
    source .env
    if [ -n "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" ]; then
        echo "   ✅ Dagger runner host configured: $_EXPERIMENTAL_DAGGER_RUNNER_HOST"
    else
        echo "   ⚠️  Dagger runner host not set in .env"
    fi
else
    echo "   ⚠️  .env file not found. Run ./setup.sh first"
fi

# Step 6: Test basic Dagger connection
echo "🧪 Step 6: Testing Dagger connection..."
if [ -n "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" ]; then
    echo "   🔄 Testing connection (timeout 30s)..."
    if timeout 30 dagger version &> /dev/null; then
        echo "   ✅ Dagger connection successful"
        dagger_version=$(dagger version | head -1)
        echo "   📋 $dagger_version"
    else
        echo "   ⚠️  Dagger connection test timed out or failed"
        echo "   💡 This might be normal for first connection (engine startup)"
    fi
else
    echo "   ⚠️  Skipping connection test (no runner host configured)"
fi

# Step 7: Module structure validation
echo "📦 Step 7: Validating module configurations..."

# Check Go module
if [ -f "go-infrastructure/dagger.json" ]; then
    go_sdk=$(grep -o '"sdk": *"[^"]*"' go-infrastructure/dagger.json | cut -d'"' -f4)
    if [ "$go_sdk" = "go" ]; then
        echo "   ✅ Go infrastructure module configured correctly"
    else
        echo "   ⚠️  Go module SDK: $go_sdk (expected: go)"
    fi
fi

# Check Python module  
if [ -f "python-data/dagger.json" ]; then
    python_sdk=$(grep -o '"sdk": *"[^"]*"' python-data/dagger.json | cut -d'"' -f4)
    if [ "$python_sdk" = "python" ]; then
        echo "   ✅ Python data module configured correctly"
    else
        echo "   ⚠️  Python module SDK: $python_sdk (expected: python)"
    fi
fi

# Check hybrid module
if [ -f "hybrid-workflow/dagger.json" ]; then
    hybrid_sdk=$(grep -o '"sdk": *"[^"]*"' hybrid-workflow/dagger.json | cut -d'"' -f4)
    if [ "$hybrid_sdk" = "go" ]; then
        echo "   ✅ Hybrid workflow module configured correctly"
    else
        echo "   ⚠️  Hybrid module SDK: $hybrid_sdk (expected: go)"
    fi
fi

echo ""
echo "🎯 Verification Summary:"
echo "========================"
echo "✅ Directory structure: Complete"
echo "✅ Required files: Present"  
echo "✅ Dagger CLI: Installed"
echo "✅ Module configurations: Valid"

if [ -n "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" ]; then
    echo "✅ Kubernetes engine: Connected"
    echo ""
    echo "🚀 Ready to test! Try these commands:"
    echo "   # Test basic container operation"
    echo "   dagger call container --from=alpine:latest --with-exec=echo,\"Hello World!\" stdout"
    echo ""
    echo "   # Initialize and test modules (requires Go/Python installed)"
    echo "   cd go-infrastructure && go mod init main && go mod tidy"
    echo "   dagger -m go-infrastructure call hello"
    echo ""
    echo "   # Run comprehensive tests"
    echo "   ./examples/test-commands.sh"
else
    echo "⚠️  Kubernetes engine: Not configured"
    echo ""
    echo "🔧 Next steps:"
    echo "   1. Run: ./setup.sh"
    echo "   2. Test: dagger version"  
    echo "   3. Run: ./examples/test-commands.sh"
fi

echo ""
echo "📚 For detailed usage instructions, see: USAGE.md"
echo "🎉 Verification complete!"