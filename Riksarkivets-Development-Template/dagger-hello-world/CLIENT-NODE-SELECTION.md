# Client-Side Node Selection for Dagger

## 🎯 Overview

Yes! You can absolutely choose which specific node to build on from the client side. Each Dagger engine pod represents a different compute node, and you can connect to any of them.

## 🖥️ Available Nodes

Current Dagger engines are running on:
- **amlpai04** - `dagger-dagger-helm-engine-mtnjt`
- **amlpai05** - `dagger-dagger-helm-engine-hfvgf`  
- **amlpai06** - `dagger-dagger-helm-engine-8c9vv`
- **amlpai07** - `dagger-dagger-helm-engine-5ws8t`
- **amlpai08** - `dagger-dagger-helm-engine-hm9ft` ⭐ *currently connected*
- **amlpai09** - `dagger-dagger-helm-engine-lbnpn`
- **amlpai10** - `dagger-dagger-helm-engine-bm9n8`

## 🔧 Quick Node Selection

### Method 1: Interactive Selection
```bash
./client-node-selection.sh
```
This script shows all available engines and lets you pick one interactively.

### Method 2: Direct Node Selection
```bash
# Connect to specific node
./quick-node-switch.sh node amlpai07
./quick-node-switch.sh node amlpai08
./quick-node-switch.sh node amlpai09

# Connect to specific pod
./quick-node-switch.sh pod dagger-dagger-helm-engine-5ws8t

# Auto-select first available
./quick-node-switch.sh auto

# Show current connection
./quick-node-switch.sh current
```

### Method 3: Manual Connection
```bash
# Set connection to specific pod directly  
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://dagger-dagger-helm-engine-5ws8t?namespace=dagger"

# Save to file
echo 'export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://dagger-dagger-helm-engine-5ws8t?namespace=dagger"' > .env
```

## 🎯 Use Cases for Node Selection

### Performance-Based Selection
```bash
# If you know amlpai08 has better CPU/memory
./quick-node-switch.sh node amlpai08

# Test performance with a build
time dagger call container --from=alpine --with-exec=echo,"Building on amlpai08!" stdout
```

### Load Balancing
```bash
# Switch between nodes to balance load
./quick-node-switch.sh node amlpai05  # Use less busy node
./quick-node-switch.sh node amlpai09  # Switch for next build
```

### Specific Hardware Requirements
```bash
# If certain nodes have GPUs or special hardware
./quick-node-switch.sh node amlpai07  # Connect to GPU node
dagger -m python-data call deep-learning-demo --framework=pytorch
```

### Development vs Production
```bash
# Use development nodes for testing
./quick-node-switch.sh node amlpai04

# Switch to production nodes for final builds
./quick-node-switch.sh node amlpai10
```

## 🔄 Workflow Examples

### Example 1: Multi-Node Build Pipeline
```bash
# Phase 1: Build on high-performance node
./quick-node-switch.sh node amlpai08
dagger -m go-infrastructure call build-image --source=git://... --tag=v1.0

# Phase 2: Test on different node  
./quick-node-switch.sh node amlpai07
dagger -m python-data call ml-pipeline --data-source="test data"

# Phase 3: Final deployment from stable node
./quick-node-switch.sh node amlpai09
dagger -m hybrid-workflow call deploy-ml-model --model-image=...
```

### Example 2: Node-Specific Workloads
```bash
# CPU-intensive Go builds on high-compute node
./quick-node-switch.sh node amlpai08
dagger -m go-infrastructure call optimized-build --source=...

# ML workloads on GPU-enabled node
./quick-node-switch.sh node amlpai07  
dagger -m python-data call deep-learning-demo --framework=pytorch

# Hybrid orchestration on dedicated node
./quick-node-switch.sh node amlpai09
dagger -m hybrid-workflow call complete-pipeline --repo=...
```

### Example 3: Development Iteration
```bash
# Quick development on nearby node
./quick-node-switch.sh node amlpai05
dagger -m go-infrastructure call hello

# Test on different architecture/configuration
./quick-node-switch.sh node amlpai10
dagger -m python-data call process-data --input-data="test"

# Final validation on production-like node
./quick-node-switch.sh node amlpai06
dagger -m hybrid-workflow call build-and-analyze --repo=...
```

## 📊 Monitoring Node Performance

### Check Node Resources
```bash
# See which nodes are busy
kubectl top nodes | grep amlpai

# Check specific node details  
kubectl describe node amlpai08 | grep -A 5 "Allocated resources"
```

### Monitor Your Builds
```bash
# Time builds on different nodes
./quick-node-switch.sh node amlpai07
time dagger call container --from=python:3.12 --with-exec=echo,"Test" stdout

./quick-node-switch.sh node amlpai08  
time dagger call container --from=python:3.12 --with-exec=echo,"Test" stdout
```

## 🔍 Troubleshooting

### Connection Issues
```bash
# Check if pod is running
kubectl get pod dagger-dagger-helm-engine-5ws8t -n dagger

# Test connection to specific pod
timeout 30 dagger version

# Switch to different node if one is having issues
./quick-node-switch.sh auto
```

### Performance Issues
```bash
# Switch to less loaded node
kubectl top nodes | grep amlpai
./quick-node-switch.sh node amlpai05  # Pick least loaded

# Monitor build performance
time dagger -m go-infrastructure call build-image --source=...
```

## 💡 Best Practices

### 1. **Know Your Nodes**
```bash
# Check available nodes regularly
./quick-node-switch.sh list

# Monitor performance differences
kubectl top nodes
```

### 2. **Match Workload to Node**
- **Go builds** → High-CPU nodes (amlpai08, amlpai07)
- **Python ML** → High-memory/GPU nodes (amlpai07, amlpai09)  
- **Hybrid workflows** → Balanced nodes (amlpai06, amlpai10)

### 3. **Load Distribution**
```bash
# Rotate between nodes for parallel work
./quick-node-switch.sh node amlpai04  # Terminal 1
./quick-node-switch.sh node amlpai05  # Terminal 2
./quick-node-switch.sh node amlpai06  # Terminal 3
```

### 4. **Backup Strategy**
```bash
# Always have backup nodes ready
./quick-node-switch.sh current  # Check current
./quick-node-switch.sh auto     # Quick fallback
```

## 🎯 Key Benefits

✅ **Performance Optimization** - Choose fastest nodes for builds  
✅ **Load Balancing** - Distribute work across cluster  
✅ **Hardware Matching** - Use GPU nodes for ML, CPU for builds  
✅ **Fault Tolerance** - Switch nodes if one has issues  
✅ **Development Flexibility** - Test on different configurations  
✅ **Resource Control** - Avoid overloading specific nodes  

## 🚀 Advanced Usage

### Custom Node Selection Logic
```bash
# Create your own selection logic
get_best_node() {
    kubectl top nodes | grep amlpai | sort -k3 -n | head -1 | awk '{print $1}'
}

best_node=$(get_best_node)
./quick-node-switch.sh node "$best_node"
echo "Connected to least loaded node: $best_node"
```

### Environment-Specific Connections
```bash
# Different nodes for different environments
case "$ENV" in
    "dev")   ./quick-node-switch.sh node amlpai04 ;;
    "test")  ./quick-node-switch.sh node amlpai05 ;;  
    "prod")  ./quick-node-switch.sh node amlpai08 ;;
esac
```

This gives you complete control over which specific compute node your Dagger builds run on! 🌟