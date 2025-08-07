# Coder Template CI Pipeline Implementation Plan

## Overview
Develop a **unified Dagger-based CI pipeline** that runs as a single unit to test Coder templates and workspace images in a local Kubernetes cluster before publishing to DockerHub. Everything will be containerized and orchestrated through Dagger functions.

## Current State Analysis

### Existing Components
- **Main Dagger Module** (`.dagger/main.go`): Builds workspace images with CPU/CUDA variants
- **Kubernetes-Local Module** (`kubernetes-local/main.go`): Provides K3s cluster with local registry
- **Workspace Template** (`Riksarkivets-Development-Template/`): Coder template configuration

### Architecture Principle
**Everything runs inside Dagger containers** - no host dependencies, fully isolated and reproducible.

## Unified Dagger Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Dagger Pipeline Container                        │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐      │
│  │   K3s Cluster   │───▶│  Build & Push   │───▶│   Deploy Coder  │      │
│  │   + Registry    │    │  Workspace Img  │    │   Platform      │      │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘      │
│           │                       │                       │             │
│           └───────────────────────────────────────────────┘             │
│                                   │                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐      │
│  │  Test Workspace │◄───│ Install Template│◄───│  Validate Setup │      │
│  │  Functionality  │    │   via Coder CLI │    │   & Readiness   │      │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
```

## Updated Dagger-First Implementation Plan

### 1. Refactored Module Structure

#### File Organization (Answer to Q1)
- **`.dagger/main.go`** - Existing build functions (keep as-is)
- **`.dagger/test.go`** - New CI pipeline functions  
- **`.dagger/k3s.go`** - K3s cluster management (copy from kubernetes-local)
- **`.dagger/coder.go`** - Coder platform deployment functions

#### Main Pipeline Function
```go
func (m *Build) TestCoderTemplate(
    ctx context.Context,
    // Template source directory
    source *dagger.Directory,
    // Image variant to test
    enableCuda bool,
    // Test configuration
    imageTag string,
) (string, error)
```

**Updated Pipeline Steps (based on feedback):**
1. Spin up K3s cluster with local registry (copy from kubernetes-local)
2. Build workspace image and push to local registry  
3. Deploy Coder v2.25.0 platform via official Helm chart + SQLite
4. Modify template to use localhost:5000 registry (dynamic)
5. Install template using Coder CLI
6. Create test workspace (basic validation only)
7. Fail fast on any error, return results

### 2. Container Registry Access Solution (Answer to Q2)

**Dagger Service Binding Approach:**
- K3s container exposes registry on port 5000
- Build containers connect via `WithServiceBinding("k3s-registry", registryService)`
- Dagger handles internal networking automatically
- Registry accessible as `k3s-registry:5000` from other containers

#### Updated Containerized Components

#### K3s + Registry Container (from kubernetes-local)
- **Base**: Existing `kubernetes-local/main.go` implementation
- **Registry**: `registry:2` sidecar container
- **Networking**: Dagger service binding
- **Access**: `localhost:5000` internally, exposed via service

#### Coder CLI Container  
- **Base**: `ubuntu:22.04` + Coder v2.25.0 CLI binary
- **Purpose**: Template management and workspace operations
- **Tools**: kubectl, helm, coder CLI, curl, jq
- **Config**: Kubeconfig from K3s service binding

#### Build Container (existing)
- **Base**: Current Dagger build container from `.dagger/main.go`
- **Registry**: Push to `k3s-registry:5000` via service binding
- **Image Tag**: `k3s-registry:5000/coder-workspace:test-latest`

### 3. Updated Implementation Structure

```go
// .dagger/test.go - Main pipeline orchestrator  
func (m *Build) TestCoderTemplate(ctx context.Context, source *dagger.Directory, enableCuda bool, imageTag string) (string, error) {
    // 1. Setup K3s + Registry (copy from kubernetes-local)
    k3sSvc := m.SetupK3sWithRegistry(ctx, "ci-test")
    
    // 2. Build and push workspace image to local registry
    imageRef := m.BuildAndPushToLocal(ctx, source, enableCuda, imageTag, k3sSvc)
    
    // 3. Deploy Coder v2.25.0 platform with SQLite
    coderSvc := m.DeployCoderPlatform(ctx, k3sSvc)
    
    // 4. Modify template to use local registry (dynamic)
    localTemplate := m.ModifyTemplateForLocal(ctx, source, imageRef)
    
    // 5. Install template via Coder CLI
    templateID := m.InstallTemplate(ctx, coderSvc, localTemplate)
    
    // 6. Create test workspace (basic validation only)
    workspaceStatus := m.CreateTestWorkspace(ctx, coderSvc, templateID)
    
    // 7. Fail fast approach - any error stops pipeline
    return workspaceStatus, nil
}

// .dagger/k3s.go - Copied from kubernetes-local/main.go
func (m *Build) SetupK3sWithRegistry(ctx context.Context, clusterName string) *dagger.Service {
    // Copy implementation from kubernetes-local/main.go KubeServer()
    return dag.K3S(clusterName).WithRegistry().Server()
}

// .dagger/coder.go - Coder platform deployment
func (m *Build) DeployCoderPlatform(ctx context.Context, k3sSvc *dagger.Service) *dagger.Service {
    return dag.Container().
        From("alpine/helm:latest").
        WithServiceBinding("k3s", k3sSvc).
        WithExec([]string{"helm", "repo", "add", "coder-v2", "https://helm.coder.com/v2"}).
        WithExec([]string{"helm", "install", "coder", "coder-v2/coder", 
            "--version", "2.25.0",
            "--set", "coder.image.tag=v2.25.0",
            "--set", "coder.env[0].name=CODER_DATABASE_URL",
            "--set", "coder.env[0].value=sqlite3:///tmp/coder.db"}).
        AsService()
}

// .dagger/test.go - Template modification for local registry
func (m *Build) ModifyTemplateForLocal(ctx context.Context, source *dagger.Directory, imageRef string) *dagger.Directory {
    // Dynamically modify main.tf to use k3s-registry:5000/coder-workspace:test-latest
    return source.WithNewFile("Riksarkivets-Development-Template/main.tf", 
        // Replace docker.io/riksarkivet/coder-workspace-ml with local registry
        strings.Replace(originalTemplate, "docker.io/riksarkivet/coder-workspace-ml", imageRef, -1))
}
```

### 4. Unified Test Execution

#### Updated Command Interface
```bash
# Test CPU variant (basic workspace creation validation)
dagger call test-coder-template --source="." --enable-cuda=false --image-tag="test-cpu"

# Test CUDA variant  
dagger call test-coder-template --source="." --enable-cuda=true --image-tag="test-cuda"

# Test with specific tag
dagger call test-coder-template --source="." --enable-cuda=false --image-tag="v14.2.0"

# After successful testing, publish to DockerHub (future step)
dagger call build-and-publish --source="." --enable-cuda=false --image-tag="v14.2.0" --username="$DOCKERHUB_USER" --password="$DOCKERHUB_TOKEN"
```

#### Updated Return Value (simplified for basic validation)
```json
{
  "status": "success",
  "duration": "6m15s", 
  "pipeline_steps": {
    "k3s_cluster": "✅ Running with registry",
    "workspace_build": "✅ Built and pushed to localhost:5000", 
    "coder_platform": "✅ v2.25.0 deployed with SQLite",
    "template_modified": "✅ Updated to use local registry",
    "template_install": "✅ Installed via Coder CLI",
    "workspace_create": "✅ Basic creation successful"
  },
  "next_steps": {
    "publish_to_dockerhub": "dagger call build-and-publish --image-tag='v14.2.0'",
    "manual_testing": "Access workspace for manual validation if needed"
  }
}
```

### 5. Benefits of Dagger-Only Approach

#### Isolation & Reproducibility
- **No host dependencies**: Everything runs in containers
- **Consistent environment**: Same results on any Docker-enabled machine
- **Clean state**: Each run starts fresh
- **Parallel safety**: Multiple pipeline runs don't interfere

#### Performance Optimization  
- **Container reuse**: Dagger caches container layers
- **Parallel execution**: Services run concurrently
- **Resource efficiency**: Only required containers running
- **Fast cleanup**: Automatic when pipeline completes

#### Developer Experience
- **Single command**: Complete test pipeline in one call
- **Real-time feedback**: Stream logs from all containers
- **Debug capability**: Inspect containers during execution
- **Portable**: Works on local dev machines and CI systems

### 6. Testing Strategy

#### Built-in Health Checks
```go
// Validate each component within Dagger
func (m *Build) validateWorkspace(ctx context.Context, workspaceID string, coderSvc *dagger.Service) string {
    validator := dag.Container().
        From("ubuntu:22.04").
        WithServiceBinding("coder", coderSvc).
        WithExec([]string{"curl", "-f", "http://coder:8080/api/v2/workspaces/" + workspaceID}).
        WithExec([]string{"curl", "-f", "http://coder:8080/api/v2/workspaces/" + workspaceID + "/apps/code-server"})
    
    return validator.Stdout(ctx)  
}
```

#### Test Scenarios as Functions
```go
func (m *Build) TestCpuWorkspace(ctx context.Context, source *dagger.Directory) (string, error)
func (m *Build) TestCudaWorkspace(ctx context.Context, source *dagger.Directory) (string, error)  
func (m *Build) TestTemplateUpdates(ctx context.Context, source *dagger.Directory) (string, error)
```

### 7. Updated Implementation Phases

#### Phase 1: File Structure & K3s Integration (1-2 days)
- Create `.dagger/test.go`, `.dagger/k3s.go`, `.dagger/coder.go` files
- Copy and adapt kubernetes-local K3s implementation  
- Test K3s cluster startup with registry

#### Phase 2: Build Integration & Local Registry (1-2 days)
- Implement `BuildAndPushToLocal()` using existing build functions
- Configure Dagger service binding for registry access
- Test image build and push to local registry

#### Phase 3: Coder Platform Deployment (1-2 days)
- Implement Coder v2.25.0 deployment via official Helm chart
- Configure SQLite database setup
- Test Coder platform startup and readiness

#### Phase 4: Template & Workspace Testing (1-2 days)
- Implement dynamic template modification for local registry
- Template installation via Coder CLI
- Basic workspace creation validation (fail fast approach)

#### Phase 5: Integration & Polish (1 day)
- Main `TestCoderTemplate()` orchestrator function
- Error handling and logging
- Documentation and usage examples

## Success Criteria

### Functional
✅ **Single Dagger command** runs complete test pipeline  
✅ **No host dependencies** beyond Docker/Dagger  
✅ **Consistent results** across different environments  
✅ **Complete isolation** - no interference between runs  
✅ **Comprehensive validation** of workspace functionality  

### Non-Functional  
✅ **Pipeline completes** in < 10 minutes  
✅ **Automatic cleanup** when pipeline finishes  
✅ **Clear success/failure** status and detailed logs  
✅ **Resource efficient** - minimal host resource usage  

## Updated Answers to Original Questions

1. ✅ **File Organization**: Refactor into multiple files (`.dagger/test.go`, `.dagger/k3s.go`, `.dagger/coder.go`) and copy from kubernetes-local
2. ✅ **Container Registry Access**: Use Dagger service binding - registry accessible as `k3s-registry:5000` 
3. ✅ **Coder Platform**: Target v2.25.0 with official Helm chart and SQLite database
4. ✅ **Template Configuration**: Dynamically modify template to use `localhost:5000` registry, add DockerHub publish step later
5. ✅ **Testing Scope**: Basic workspace creation validation only (can iterate later)
6. ✅ **Module Structure**: Multiple files in `.dagger/` directory with clear separation of concerns
7. ✅ **Error Handling**: Fail fast approach - stop pipeline on first error
8. ✅ **Resources**: Use defaults, focus on functionality first

## Next Steps - Ready for Implementation

1. **Start with Phase 1**: Create file structure and copy K3s implementation
2. **Iterative Development**: Build and test each phase incrementally  
3. **Test Early**: Validate K3s + registry setup before moving to Coder deployment

---

**Status**: Plan updated based on feedback - Ready to begin implementation