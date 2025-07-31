# Dagger Engine Node Selection Guide

## 🎯 Current Status
The Dagger engine is currently running as a **DaemonSet on all 7 nodes** with no node selectors.

## 🔧 Node Selection Options

### Option 1: Node Labels (Recommended)
Target specific nodes using labels:

```bash
# First, check available nodes (requires cluster admin)
kubectl get nodes --show-labels

# Label nodes for Dagger engine (example)
kubectl label nodes worker-node-1 dagger-engine=true
kubectl label nodes worker-node-2 dagger-engine=true
kubectl label nodes worker-node-3 dagger-engine=true

# Update Dagger DaemonSet with node selector
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.dagger-engine=true
```

### Option 2: Instance Types
Target nodes with specific instance types:

```bash
# Target nodes with high compute capacity
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.node\\.kubernetes\\.io/instance-type=c5.xlarge

# Or target GPU nodes for ML workloads
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.accelerator=nvidia-tesla-k80
```

### Option 3: Node Affinity (Advanced)
More flexible node selection:

```yaml
# Create custom values file: dagger-node-affinity.yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: node-role.kubernetes.io/worker
        operator: In
        values: ["true"]
      - key: node.kubernetes.io/instance-type
        operator: In
        values: ["c5.large", "c5.xlarge", "c5.2xlarge"]
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    preference:
      matchExpressions:
      - key: dagger-preferred
        operator: In
        values: ["true"]

# Apply with Helm
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  -f dagger-node-affinity.yaml
```

### Option 4: Resource-Based Selection
Target nodes with sufficient resources:

```bash
# Target nodes with at least 4 CPU cores and 8GB RAM
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set resources.requests.cpu=2 \
  --set resources.requests.memory=4Gi \
  --set resources.limits.cpu=4 \
  --set resources.limits.memory=8Gi
```

## 🏗️ Practical Examples

### Example 1: Dedicated Build Nodes
```bash
# Label specific nodes as build nodes
kubectl label nodes build-node-1 workload-type=build
kubectl label nodes build-node-2 workload-type=build
kubectl label nodes build-node-3 workload-type=build

# Deploy Dagger only to build nodes
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.workload-type=build
```

### Example 2: High-Performance Nodes
```bash
# Target high-performance compute nodes
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.node\\.kubernetes\\.io/instance-type=c5n.xlarge
```

### Example 3: GPU-Enabled Nodes (For ML Workloads)
```bash
# Target GPU nodes for ML pipeline builds
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.accelerator=nvidia-tesla-v100
```

### Example 4: Zone-Specific Deployment
```bash
# Deploy to specific availability zone
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.topology\\.kubernetes\\.io/zone=us-west-2a
```

## 🔄 Migration Strategy

### Step 1: Check Current Deployment
```bash
# See current node distribution
kubectl get pods -n dagger -o wide

# Check resource usage
kubectl top pods -n dagger
```

### Step 2: Plan Node Selection
```bash
# Identify target nodes (requires admin access)
kubectl get nodes -o custom-columns=NAME:.metadata.name,INSTANCE:.metadata.labels.node\\.kubernetes\\.io/instance-type,ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone
```

### Step 3: Apply Node Selection
```bash
# Example: Select 3 high-performance nodes
kubectl label nodes node-1 dagger-engine=preferred
kubectl label nodes node-2 dagger-engine=preferred  
kubectl label nodes node-3 dagger-engine=preferred

helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.dagger-engine=preferred
```

### Step 4: Verify New Deployment
```bash
# Check pods are running on selected nodes only
kubectl get pods -n dagger -o wide

# Verify our connection still works
cd dagger-hello-world
source .env
dagger version
```

## 💡 Recommendations

### For Development Environment:
```bash
# Light resource usage, any worker node
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.node-role\\.kubernetes\\.io/worker=true
```

### For Production Environment:
```bash
# Dedicated high-performance nodes
kubectl label nodes prod-build-1 workload=dagger-engine
kubectl label nodes prod-build-2 workload=dagger-engine
kubectl label nodes prod-build-3 workload=dagger-engine

helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.workload=dagger-engine \
  --set resources.requests.cpu=2 \
  --set resources.requests.memory=4Gi \
  --set resources.limits.cpu=8 \
  --set resources.limits.memory=16Gi
```

### For ML/AI Workloads:
```bash
# GPU-enabled nodes with high memory
helm upgrade dagger oci://registry.dagger.io/dagger-helm \
  -n dagger \
  --set nodeSelector.accelerator=nvidia-tesla-v100 \
  --set resources.requests.memory=8Gi \
  --set resources.limits.memory=32Gi
```

## 🔍 Monitoring After Change

### Check New Pod Distribution:
```bash
# See which nodes are now running Dagger
kubectl get pods -n dagger -o wide

# Verify resource utilization
kubectl top nodes
kubectl top pods -n dagger
```

### Test Connection:
```bash
cd dagger-hello-world
source .env

# Test connection (may need to update pod name in .env)
dagger version

# Update connection if needed
./setup.sh
```

## ⚠️ Important Notes

1. **Connection Update**: After changing node selection, you may need to run `./setup.sh` again to get the new pod name
2. **Resource Planning**: Ensure selected nodes have sufficient resources for your workloads
3. **High Availability**: Consider running on multiple selected nodes for redundancy
4. **Performance**: Dedicated nodes typically provide better performance than shared nodes

## 🎯 Benefits of Targeted Node Selection

✅ **Performance Optimization** - Use high-performance nodes for builds  
✅ **Cost Control** - Run on cost-effective instance types  
✅ **Resource Isolation** - Separate build workloads from applications  
✅ **GPU Utilization** - Target GPU nodes for ML workflows  
✅ **Zone Control** - Control availability zone placement  
✅ **Scaling Strategy** - Easy to scale by adding/removing labeled nodes  

This gives you full control over where your Dagger engines run while maintaining the hybrid Go + Python workflow capabilities! 🚀