# Dagger Hello World - Hybrid Go + Python Example

This demonstrates a powerful hybrid approach using both Go and Python Dagger modules connected to a Kubernetes engine.

## 🏗️ Architecture

```
dagger-hello-world/
├── go-infrastructure/     # 🔧 Go for DevOps & Infrastructure
│   ├── dagger.json       # Container building, Kubernetes ops
│   └── main.go           # Docker-free builds with Kaniko
├── python-data/          # 🐍 Python for Data Processing  
│   ├── dagger.json       # ML pipelines, data transformation
│   └── main.py           # NumPy, pandas, ML libraries
├── hybrid-workflow/      # 🚀 Orchestration Layer
│   ├── dagger.json       # Combines Go + Python modules
│   └── main.go           # Cross-language function calls
└── examples/             # 📚 Usage Examples
```

## 🎯 Why This Hybrid Approach?

### Go Infrastructure Module Benefits:
✅ **Docker-free building** - Kaniko integration, no Docker daemon  
✅ **Kubernetes native** - Direct containerd integration  
✅ **High performance** - Compiled binaries, fast execution  
✅ **Type safety** - Compile-time error detection  
✅ **Small memory footprint** - Efficient in K8s environments  

### Python Data Module Benefits:
✅ **Rich ecosystem** - NumPy, pandas, scikit-learn, PyTorch  
✅ **Data processing** - Natural fit for ML and analytics  
✅ **Rapid prototyping** - Interactive development style  
✅ **Scientific computing** - Mature libraries and tooling  

### Hybrid Workflow Benefits:
✅ **Best of both worlds** - Go speed + Python ecosystem  
✅ **Shared Dagger engine** - One K8s infrastructure serves both  
✅ **Cross-language calls** - Go can call Python and vice versa  
✅ **Unified pipeline** - Single orchestration layer  

## 🚀 Quick Start

### 1. Set up Kubernetes Engine Connection
```bash
./setup.sh
```

### 2. Test Individual Modules
```bash
# Go infrastructure operations
dagger -m go-infrastructure call build-image --source=git://github.com/example/repo

# Python data processing  
dagger -m python-data call process-data --input="sample data"

# Cross-language hybrid workflow
dagger -m hybrid-workflow call complete-pipeline --repo=... --data=...
```

### 3. Example Use Cases
```bash
# Build + analyze pipeline
dagger -m hybrid-workflow call build-and-analyze \
  --repo="https://github.com/example/ml-project" \
  --model-data="training-data.csv"

# Infrastructure + ML deployment
dagger -m hybrid-workflow call deploy-ml-model \
  --model-image="registry.ra.se:5002/ml-model:v1.0" \
  --k8s-manifest="deployment.yaml"
```

## 🔗 Cross-Language Integration

The hybrid approach eliminates the artificial separation between infrastructure and data science:

- **Go handles**: Container building, Kubernetes deployment, performance-critical operations
- **Python handles**: Data processing, ML training, scientific computing  
- **Workflow orchestrates**: Seamless integration between both languages

This replaces complex Argo workflows with a single, unified pipeline that developers can run interactively from their workspace!