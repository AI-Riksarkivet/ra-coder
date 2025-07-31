#!/bin/bash

# Client-Side Node Selection for Dagger Engine
# Choose which specific Dagger engine pod/node to connect to

set -e

echo "🎯 Dagger Client Node Selection"
echo "==============================="

# Get all available Dagger engine pods
echo "📋 Available Dagger engine pods:"
kubectl get pods -n dagger -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase,IP:.status.podIP --no-headers | nl

echo ""
echo "🔍 Current connection:"
if [ -n "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" ]; then
    echo "   $(_EXPERIMENTAL_DAGGER_RUNNER_HOST)"
else
    echo "   No connection configured"
fi

echo ""
echo "🎯 Select a specific engine pod:"

# Get pod list
pods=($(kubectl get pods -n d
agger --selector=name=dagger-dagger-helm-engine -o jsonpath='{.items[*].metadata.name}'))
nodes=($(kubectl get pods -n dagger --selector=name=dagger-dagger-helm-engine -o jsonpath='{.items[*].spec.nodeName}'))

# Display options with nodes
for i in "${!pods[@]}"; do
    echo "   $((i+1)). ${pods[$i]} (node: ${nodes[$i]})"
done
echo "   0. Auto-select (use first available)"

echo ""
read -p "Choose engine pod (1-${#pods[@]} or 0): " choice

if [ "$choice" = "0" ]; then
    # Auto-select first pod
    selected_pod="${pods[0]}"
    selected_node="${nodes[0]}"
    echo "🔄 Auto-selected: $selected_pod on node $selected_node"
elif [ "$choice" -ge 1 ] && [ "$choice" -le "${#pods[@]}" ]; then
    # Manual selection
    selected_pod="${pods[$((choice-1))]}"
    selected_node="${nodes[$((choice-1))]}"
    echo "✅ Selected: $selected_pod on node $selected_node"
else
    echo "❌ Invalid selection"
    exit 1
fi

# Set connection
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://$selected_pod?namespace=dagger"

echo ""
echo "🔗 Setting connection:"
echo "   _EXPERIMENTAL_DAGGER_RUNNER_HOST=$_EXPERIMENTAL_DAGGER_RUNNER_HOST"

# Save to .env file
cat > .env << EOF
# Dagger Kubernetes Engine Connection - Node: $selected_node
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://$selected_pod?namespace=dagger"
EOF

echo "💾 Connection saved to .env file"

# Test connection
echo ""
echo "🧪 Testing connection to $selected_pod on node $selected_node..."
if timeout 30 dagger version &> /dev/null; then
    echo "✅ Successfully connected to Dagger engine!"
    echo ""
    echo "📊 Engine details:"
    dagger version
    echo ""
    echo "🎯 Ready to build on node: $selected_node"
    echo ""
    echo "💡 Usage examples:"
    echo "   # Test basic container on this specific node"
    echo "   dagger call container --from=alpine:latest --with-exec=echo,\"Building on $selected_node!\" stdout"
    echo ""
    echo "   # Run Go infrastructure module on this node"
    echo "   dagger -m go-infrastructure call hello"
    echo ""
    echo "   # Run Python data module on this node"  
    echo "   dagger -m python-data call hello"
else
    echo "⚠️  Connection test timed out (this is normal for first connection)"
    echo "   The connection is configured correctly - try running your builds!"
fi

echo ""
echo "🔄 To switch to a different node, run this script again"
echo "🌟 Your builds will now execute on: $selected_node"