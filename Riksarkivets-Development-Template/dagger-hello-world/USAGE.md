# Dagger Hello World - Usage Guide

## 🎯 Quick Start

### 1. Set up Kubernetes Engine Connection
```bash
cd dagger-hello-world
./setup.sh
```

### 2. Test Individual Modules

#### Go Infrastructure Module
```bash
# Basic hello
dagger -m go-infrastructure call hello

# Container info
dagger -m go-infrastructure call container-info

# Build an image (Docker-free with Kaniko)
dagger -m go-infrastructure call build-image \
  --source=git://github.com/docker/getting-started \
  --registry="registry.ra.se:5002" \
  --repository="test-app" \
  --tag="v1.0"

# Get Git source
dagger -m go-infrastructure call git-source \
  --repo="https://github.com/docker/getting-started" \
  --ref="main"
```

#### Python Data Module  
```bash
# Basic hello
dagger -m python-data call hello

# Process data
dagger -m python-data call process-data \
  --input-data="Sample data for analysis" \
  --operation="analyze"

# Run ML pipeline
dagger -m python-data call ml-pipeline \
  --data-source="training dataset" \
  --model-type="classification"

# Data visualization
dagger -m python-data call data-visualization \
  --dataset-name="production_data"

# Deep learning demo
dagger -m python-data call deep-learning-demo \
  --framework="pytorch"
```

#### Hybrid Workflow (Cross-Language)
```bash
# Basic hello (calls both Go and Python)
dagger -m hybrid-workflow call hello

# Complete build + analysis pipeline
dagger -m hybrid-workflow call build-and-analyze \
  --repo="https://github.com/docker/getting-started" \
  --analysis-data="ML training data for analysis" \
  --registry="registry.ra.se:5002" \
  --repository="ml-app" \
  --tag="v1.0"

# Deploy ML model
dagger -m hybrid-workflow call deploy-ml-model \
  --model-image="registry.ra.se:5002/ml-model:v1.0" \
  --namespace="ml-production"

# Complete development-to-production pipeline
dagger -m hybrid-workflow call complete-pipeline \
  --repo="https://github.com/example/ml-project" \
  --training-data="production dataset" \
  --registry="registry.ra.se:5002" \
  --repository="ml-pipeline" \
  --tag="v2.0"
```

### 3. Run Automated Tests
```bash
cd examples
./test-commands.sh
```

## 🏗️ Architecture Benefits

### Traditional Argo Approach Problems:
❌ **Parameter size limits** - Large Dockerfiles exceed parameter limits  
❌ **No version control** - Parameter content isn't tied to Git commits  
❌ **Security concerns** - Dockerfile content in workflow parameters  
❌ **Debugging difficulty** - Hard to trace which version was used  
❌ **Complex workflows** - Large parameters make workflows unreadable  

### Dagger Hybrid Solution Benefits:
✅ **Docker-free building** - Uses Kaniko, no Docker daemon required  
✅ **Git-native source** - Direct repository access, no parameters  
✅ **Interactive development** - Real-time builds from workspace  
✅ **Cross-language integration** - Go + Python in unified pipeline  
✅ **Shared infrastructure** - One Kubernetes engine serves all  
✅ **Type safety** - Compile-time validation prevents runtime errors  
✅ **Performance** - Go speed + Python ecosystem richness  

## 🔧 Troubleshooting

### Connection Issues
```bash
# Check if Dagger engine is running
kubectl get pods -n dagger

# Verify connection
dagger version

# Re-run setup if needed
./setup.sh
```

### Module Issues
```bash
# Clean and regenerate modules
dagger develop --sdk=go   # for Go modules
dagger develop --sdk=python  # for Python modules
```

### Timeout Issues
```bash
# First runs may take longer due to image pulls
# Subsequent runs will be faster due to caching
```

## 🚀 Next Steps

1. **Customize for your use case** - Modify the modules for your specific needs
2. **Add more functions** - Extend with your own Go and Python functions  
3. **Integrate with existing tools** - Connect to your CI/CD systems
4. **Scale up** - Use the same pattern for production workloads
5. **Replace Argo workflows** - Migrate from complex YAML to programmable pipelines

This hybrid approach demonstrates the future of DevOps + Data Science integration! 🌟