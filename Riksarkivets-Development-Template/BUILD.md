# Build Guide - Dagger + Kaniko Pipeline

This guide explains how to build container images using the Git-based Dagger + Kaniko pipeline that replaces the old Argo Workflows system.

## 🚀 Quick Start

### Prerequisites
- Dagger is configured and connected to the Kubernetes engine
- SSH key available at `~/.ssh/id_rsa` for Git authentication (auto-detected)
- Access to the target registry (`registry.ra.se:5002`)

### Basic Build Commands

```bash
# Build with default settings (CUDA enabled, latest tag)
dagger call build-from-git --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"

# Build CPU-only version
dagger call build-from-git --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" --enable-cuda=false

# Build with custom tag
dagger call build-from-git --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" --image-tag=v15.0.0
```

## 📋 Build Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `git-repo` | Required | Git repository URL (SSH format) |
| `git-ref` | `main` | Git branch, tag, or commit |
| `ssh-private-key` | Auto-detected from `~/.ssh/id_rsa` | SSH private key for authentication |
| `enable-cuda` | `true` | Enable CUDA support (adds `-cpu` suffix if false) |
| `registry` | `registry.ra.se:5002` | Target registry URL |
| `image-repository` | `airiksarkivet/devenv` | Image repository name |
| `image-tag` | `v14.1.1` | Base image tag |
| `verbosity` | `info` | Kaniko build verbosity level |

## 🛠️ Build Examples

### Standard Builds

```bash
# Current production build (CUDA enabled) - SSH key auto-detected
dagger call build-from-git \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" \
  --enable-cuda=true \
  --image-tag=v14.1.1

# CPU-only build for development
dagger call build-from-git \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" \
  --enable-cuda=false \
  --image-tag=v14.1.1-dev
```

### Custom Configurations

```bash
# Build from different branch/tag
dagger call build-from-git \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" \
  --git-ref="feature/new-feature" \
  --image-tag=v2.0.0-beta

# Build for different registry
dagger call build-from-git \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" \
  --registry=my-registry.com:5000 \
  --image-repository=myorg/myapp \
  --enable-cuda=false

# Build with explicit SSH key (overrides auto-detection)
dagger call build-from-git \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" \
  --ssh-private-key="$(cat ~/.ssh/custom_key)" \
  --image-tag=v15.0.0
```

### Quick Build Functions

```bash
# Shortcut for CUDA build from Git
dagger call build-cuda \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"

# Shortcut for CPU build from Git
dagger call build-cpu \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"
```

## 🔄 Migration from build.sh

### Old Argo Workflow Method
```bash
# Old way (Argo Workflows)
./build.sh false devenv v14.0.0 registry.ra.se:5002
```

### New Dagger Method
```bash
# New way (Dagger + Kaniko)
dagger call build-image \
  --dockerfile-content="$(cat Dockerfile)" \
  --enable-cuda=false \
  --service-name=devenv \
  --image-tag=v14.1.1 \
  --registry=registry.ra.se:5002
```

### Using the build-dagger.sh Script
```bash
# Direct replacement for build.sh
./build-dagger.sh false devenv v14.0.0 registry.ra.se:5002
```

## 📊 Understanding Image Tags

The pipeline automatically handles image tagging:

| CUDA Setting | Base Tag | Final Tag |
|-------------|----------|-----------|
| `true` | `v14.0.0` | `registry.ra.se:5002/airiksarkivet/devenv:v14.0.0` |
| `false` | `v14.0.0` | `registry.ra.se:5002/airiksarkivet/devenv:v14.0.0-cpu` |

## 🔍 Build Process Details

### What Happens During a Build

1. **Dagger Connection**: Connects to Kubernetes engine via TCP
2. **Dockerile Processing**: Injects Dockerfile content into build context
3. **Kaniko Execution**: Runs official Kaniko executor container
4. **Image Build**: Builds using Dockerfile with build args
5. **Registry Push**: Pushes to target registry using HTTP/insecure mode
6. **Verification**: Returns build output and success confirmation

### Build Arguments Passed to Docker

```dockerfile
ARG ENABLE_CUDA=true    # or false based on --enable-cuda
ARG REGISTRY=registry.ra.se:5002
```

### Kaniko Configuration

The pipeline uses these Kaniko flags:
- `--context=dir:///workspace` - Build context directory
- `--dockerfile=/workspace/Dockerfile` - Dockerfile location
- `--destination=...` - Target image name
- `--insecure` - Allow HTTP registry connections
- `--insecure-registry=registry.ra.se:5002` - Specific insecure registry
- `--skip-tls-verify-registry=registry.ra.se:5002` - Skip TLS verification

## 🚨 Troubleshooting

### Common Issues

#### 1. Registry Connection Problems
```bash
# Error: tls: first record does not look like a TLS handshake
# Solution: Registry is HTTP-only, pipeline handles this automatically
```

#### 2. Dockerfile Not Found
```bash
# Error: Make sure you're in a directory with a Dockerfile
ls -la Dockerfile  # Verify file exists
```

#### 3. Permission Issues
```bash
# Error: Kaniko cannot push to registry
# Solution: Check registry permissions and network access
```

#### 4. SSH Authentication Issues
```bash
# Error: SSH URLs are not supported without an SSH socket
# Solution: Use explicit SSH key method
dagger call build-cpu \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" \
  --ssh-private-key="$(cat ~/.ssh/id_rsa)"
```

#### 5. Build Timeouts
```bash
# Large builds may take time, monitor progress:
dagger call build-from-git --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" | tee build.log
```

### Debugging Commands

```bash
# Test Dagger connection
dagger version

# Test basic container functionality
dagger call hello

# Generate build command without executing
dagger call get-dagger-build-command --enable-cuda=false

# Check registry connectivity
curl -k http://registry.ra.se:5002/v2/airiksarkivet/devenv/tags/list
```

## 📈 Performance Comparison

| Aspect | Old (Argo) | New (Dagger) |
|--------|------------|--------------|
| **Setup** | Complex YAML + RBAC | Simple Go module |
| **Execution** | Kubernetes Job | Direct container |
| **Debugging** | `kubectl logs` | Direct output |
| **Dependencies** | Argo Workflows | Dagger engine |
| **Source Size** | 32KB limit | Unlimited (Git-based) |
| **Build Time** | ~8-12 minutes | ~8-10 minutes |
| **Resource Usage** | Job overhead | Direct execution |

## ⚙️ System Architecture Changes

### 🚫 **Caching Disabled** 
- **Kaniko caching is disabled** to prevent layer inconsistencies
- Builds are slower but more reliable and predictable
- No cache-related debugging needed
- Every build is fresh and reproducible

### 🔑 **SSH Authentication**
- SSH key is **automatically read from `~/.ssh/id_rsa`**
- Supports both SSH agent forwarding and explicit key methods
- Auto-detection works in most environments
- Fallback to explicit key in containerized environments

#### SSH Authentication Methods

**Method 1: SSH Agent (Preferred)**
```bash
# Works when SSH agent is available
dagger call build-cpu \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"
```

**Method 2: Explicit SSH Key**
```bash
# Works in containerized environments without SSH agent
dagger call build-cpu \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" \
  --ssh-private-key="$(cat ~/.ssh/id_rsa)"
```

**When to use each method:**
- ✅ **SSH Agent**: Local development, CI/CD with agent, workspaces with forwarding
- 🔧 **Explicit Key**: Containerized Dagger, automated scripts, no SSH agent available

### 📁 **Git-Based Source Only**
- All builds use Git repository as the source of truth
- No more passing Dockerfile content as parameters
- Supports branches, tags, and commit hashes
- Ensures consistent builds across environments

### 🏗️ **Simplified Build Functions**
- Removed `build-from-dockerfile` (deprecated)
- Primary function: `build-from-git`
- Shortcut functions: `build-cuda`, `build-cpu`
- All functions use same Git-based approach

## 🎯 Best Practices

### 1. **Version Your Builds**
```bash
# Use semantic versioning
dagger call build-from-git \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" \
  --image-tag=v14.1.1

# Include build metadata with commit hash
dagger call build-from-git \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" \
  --image-tag=v14.1.1-$(git rev-parse --short HEAD)
```

### 2. **Environment-Specific Builds**
```bash
# Development builds (CPU-only, fast)
dagger call build-cpu \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"

# Production builds (CUDA-enabled, full)
dagger call build-cuda \
  --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"
```

### 3. **Build Validation**
```bash
# Verify image after build
IMAGE_TAG=v14.0.0-cpu
curl -k "http://registry.ra.se:5002/v2/airiksarkivet/devenv/manifests/$IMAGE_TAG"
```

### 4. **Automated Builds**
```bash
#!/bin/bash
# automated-build.sh
set -e

VERSION=$(git describe --tags --always)
echo "Building version: $VERSION"

# Build both variants
dagger call build-image \
  --dockerfile-content="$(cat Dockerfile)" \
  --enable-cuda=true \
  --image-tag="$VERSION"

dagger call build-image \
  --dockerfile-content="$(cat Dockerfile)" \
  --enable-cuda=false \
  --image-tag="$VERSION"

echo "✅ Both CUDA and CPU images built successfully!"
```

## 🔗 Related Documentation

- [DAGGER_SOLUTION_SUMMARY.md](../DAGGER_SOLUTION_SUMMARY.md) - Technical implementation details
- [Dagger Documentation](https://docs.dagger.io/) - Official Dagger docs
- [Kaniko Documentation](https://github.com/GoogleContainerTools/kaniko) - Kaniko build tool

---

**Need help?** The Dagger pipeline is designed to be simpler and more reliable than the old Argo Workflows system. If you encounter issues, check the troubleshooting section above or examine the build logs for specific error messages.