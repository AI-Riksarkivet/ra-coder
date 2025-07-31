#!/bin/bash

# Quick Node Switching for Dagger Client
# Fast way to switch between different engine nodes

set -e

# Function to set connection to specific node
connect_to_node() {
    local node_name="$1"
    local pod_name=$(kubectl get pods -n dagger --selector=name=dagger-dagger-helm-engine -o jsonpath="{.items[?(@.spec.nodeName=='$node_name')].metadata.name}")
    
    if [ -n "$pod_name" ]; then
        export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://$pod_name?namespace=dagger"
        echo "export _EXPERIMENTAL_DAGGER_RUNNER_HOST=\"kube-pod://$pod_name?namespace=dagger\"" > .env
        echo "✅ Connected to $pod_name on node $node_name"
        echo "   Connection: $_EXPERIMENTAL_DAGGER_RUNNER_HOST"
        return 0
    else
        echo "❌ No Dagger engine pod found on node $node_name"
        return 1
    fi
}

# Function to connect to specific pod directly
connect_to_pod() {
    local pod_name="$1"
    local node_name=$(kubectl get pod "$pod_name" -n dagger -o jsonpath='{.spec.nodeName}' 2>/dev/null)
    
    if [ -n "$node_name" ]; then
        export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://$pod_name?namespace=dagger"
        echo "export _EXPERIMENTAL_DAGGER_RUNNER_HOST=\"kube-pod://$pod_name?namespace=dagger\"" > .env
        echo "✅ Connected to $pod_name on node $node_name"
        echo "   Connection: $_EXPERIMENTAL_DAGGER_RUNNER_HOST"
        return 0
    else
        echo "❌ Pod $pod_name not found in dagger namespace"
        return 1
    fi
}

# Main logic
case "$1" in
    "node")
        if [ -z "$2" ]; then
            echo "Usage: $0 node <node-name>"
            echo "Available nodes:"
            kubectl get pods -n dagger -o custom-columns=NODE:.spec.nodeName --no-headers | sort | uniq
            exit 1
        fi
        connect_to_node "$2"
        ;;
    "pod")
        if [ -z "$2" ]; then
            echo "Usage: $0 pod <pod-name>"
            echo "Available pods:"
            kubectl get pods -n dagger --selector=name=dagger-dagger-helm-engine -o name | sed 's/pod\///'
            exit 1
        fi
        connect_to_pod "$2"
        ;;
    "list")
        echo "🎯 Available Dagger Engine Nodes:"
        kubectl get pods -n dagger -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase,IP:.status.podIP
        echo ""
        echo "💡 Usage:"
        echo "   $0 node <node-name>    # Connect to engine on specific node"
        echo "   $0 pod <pod-name>      # Connect to specific pod"
        echo "   $0 auto               # Auto-select best available engine"
        ;;
    "auto")
        # Auto-select first running pod
        pod_name=$(kubectl get pods -n dagger --selector=name=dagger-dagger-helm-engine --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
        if [ -n "$pod_name" ]; then
            connect_to_pod "$pod_name"
        else
            echo "❌ No running Dagger engine pods found"
            exit 1
        fi
        ;;
    "current")
        if [ -n "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" ]; then
            echo "🔗 Current connection: $_EXPERIMENTAL_DAGGER_RUNNER_HOST"
            # Extract pod name from connection string
            pod_name=$(echo "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" | sed 's/kube-pod:\/\/\([^?]*\).*/\1/')
            if [ -n "$pod_name" ]; then
                node_name=$(kubectl get pod "$pod_name" -n dagger -o jsonpath='{.spec.nodeName}' 2>/dev/null)
                if [ -n "$node_name" ]; then
                    echo "📍 Connected to pod: $pod_name"
                    echo "🖥️  Running on node: $node_name"
                fi
            fi
        else
            echo "❌ No Dagger connection configured"
            echo "💡 Run: source .env  or  ./setup.sh"
        fi
        ;;
    *)
        echo "🎯 Dagger Client Node Selection"
        echo "==============================="
        echo ""
        echo "Commands:"
        echo "  $0 list                    # Show all available engines"
        echo "  $0 node <node-name>        # Connect to engine on specific node"
        echo "  $0 pod <pod-name>          # Connect to specific pod"
        echo "  $0 auto                   # Auto-select first available engine"
        echo "  $0 current                # Show current connection"
        echo ""
        echo "Examples:"
        echo "  $0 node amlpai07          # Use engine on node amlpai07"
        echo "  $0 pod dagger-engine-abc  # Use specific pod"
        echo "  $0 auto                   # Quick auto-selection"
        echo ""
        echo "After connecting, test with:"
        echo "  dagger version"
        echo "  dagger call container --from=alpine --with-exec=echo,\"Hello!\" stdout"
        ;;
esac