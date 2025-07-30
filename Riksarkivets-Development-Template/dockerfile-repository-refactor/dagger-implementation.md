# Dagger Implementation Option - Dockerfile Repository Refactor

## 🎯 **Dagger Overview**

[Dagger](https://dagger.io) is a programmable CI/CD engine that runs pipelines in containers. It provides:
- **Reproducible builds** - Same pipeline, same results everywhere
- **Language flexibility** - Write pipelines in Go, Python, TypeScript, etc.
- **Container-native** - Built for containerized workloads
- **Local development** - Run CI/CD pipelines locally
- **Cloud-agnostic** - Works with any container runtime

## 🚀 **Why Dagger for This Refactor?**

### Current Challenge
```yaml
# Current approach - complex Argo workflow
dockerfileContent="$(cat Dockerfile)"  # Parameter size limits
argo submit -p dockerfileContent="$dockerfileContent"  # Security concerns
```

### Dagger Solution (Docker-Free)
```go
// Simple, programmatic pipeline using Kaniko - no Docker daemon needed
func (m *Build) BuildImage(ctx context.Context, repo, registry, tag string) *Container {
    // Get source from Git
    source := dag.Git(repo).Tree()
    
    // Use Kaniko for Docker-free building
    return dag.Container().
        From("gcr.io/kaniko-project/executor:latest").
        WithMountedDirectory("/workspace", source).
        WithExec([]string{
            "/kaniko/executor",
            "--context=/workspace",
            "--dockerfile=/workspace/Dockerfile",
            "--destination=" + registry + "/" + tag,
        })
}
```

### Key Benefits
✅ **Docker-free solution** - Uses Kaniko, no Docker daemon required  
✅ **Kubernetes native** - Leverages existing containerd infrastructure  
✅ **Eliminates parameter passing** - Source code directly from Git  
✅ **Native Git integration** - Built-in Git repository handling  
✅ **Interactive development** - Real-time builds from workspace  
✅ **Shared engine** - Multiple developers use same infrastructure  
✅ **Better debugging** - Programmatic control and error handling  
✅ **Persistent cache** - Engine cache survives across sessions  
✅ **Type safety** - Compile-time validation of pipeline logic  
✅ **No Argo complexity** - Direct pipeline execution  

## 🏗️ **Implementation Architecture**

### Option 1: Pure Dagger with Kubernetes Engine (🌟 RECOMMENDED)
```bash
# Direct Dagger execution from workspace - no Argo needed!
# Connect to Kubernetes-deployed Dagger engine
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://$DAGGER_ENGINE_POD_NAME?namespace=dagger"

# Run builds directly from development workspace
dagger call build-image \
  --source=git://https://devops.ra.se/DataLab/Datalab/_git/coder-templates#main \
  --registry=registry.ra.se:5002 \
  --repository=airiksarkivet/devenv \
  --tag=v13.6.0
```

#### Key Advantages of Pure Dagger Approach:
✅ **No Argo workflows needed** - Direct pipeline execution  
✅ **Development-friendly** - Run from any workspace pod  
✅ **Shared engine** - Multiple users leverage same Dagger engine  
✅ **Persistent cache** - Engine cache survives across sessions  
✅ **Real-time feedback** - Interactive development experience  
✅ **Simplified deployment** - One Helm chart, no workflow management  

### Option 2: Dagger + Argo Hybrid (Traditional CI/CD)
```yaml
# For teams preferring traditional CI/CD workflows
apiVersion: argoproj.io/v1alpha1
kind: Workflow
spec:
  templates:
  - name: dagger-build
    container:
      image: dagger/dagger:latest
      command: [dagger]
      args: ["call", "build-image", 
             "--repo={{workflow.parameters.gitRepo}}",
             "--registry={{workflow.parameters.registry}}",
             "--repository={{workflow.parameters.imageRepository}}",
             "--tag={{workflow.parameters.imageTag}}"]
      env:
      - name: _EXPERIMENTAL_DAGGER_RUNNER_HOST
        value: "kube-pod://dagger-engine-pod?namespace=dagger"
```

## 🏗️ **Kubernetes Engine Architecture**

### Dagger Engine Deployment
```yaml
# Deployed via Helm chart as DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dagger-engine
  namespace: dagger
spec:
  template:
    spec:
      # Access to node's container runtime
      hostNetwork: true
      containers:
      - name: dagger-engine
        image: registry.dagger.io/engine:latest
        securityContext:
          privileged: true  # Access to containerd socket
        volumeMounts:
        - name: containerd-socket
          mountPath: /run/containerd/containerd.sock
        - name: dagger-cache
          mountPath: /var/cache/dagger
      volumes:
      - name: containerd-socket
        hostPath:
          path: /run/containerd/containerd.sock
      - name: dagger-cache
        hostPath:
          path: /var/cache/dagger
```

### Connection Architecture
```bash
# From any workspace pod in the cluster:
# 1. Discover engine pod
DAGGER_ENGINE_POD=$(kubectl get pod -l name=dagger-dagger-helm-engine -n dagger -o name)

# 2. Connect via kube-pod protocol
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://$DAGGER_ENGINE_POD?namespace=dagger"

# 3. Execute pipelines directly
dagger call build-image --repo=git://... --tag=v1.0.0
```

### Multi-User Support
- **Shared Engine**: One DaemonSet serves all developers
- **Session Isolation**: Each dagger call gets isolated execution
- **Persistent Cache**: Shared layer cache improves performance
- **Resource Efficiency**: No per-user engine overhead

## 🔧 **Dagger Pipeline Implementation**

### Basic Dagger Module (Go)
```go
// dagger/main.go
package main

import (
    "context"
    "fmt"
)

type Build struct{}

// BuildImage builds a container image using Kaniko
func (m *Build) BuildImage(
    ctx context.Context,
    // Git repository source
    source *Directory,
    // Image registry and tag
    registry string,
    repository string,
    tag string,
    // Optional: enable CUDA support
    // +default=true
    enableCuda bool,
) (*Container, error) {
    
    imageTag := fmt.Sprintf("%s/%s:%s", registry, repository, tag)
    if !enableCuda {
        imageTag += "-cpu"
    }
    
    // Build using Kaniko
    return dag.Container().
        From("gcr.io/kaniko-project/executor:latest").
        WithMountedDirectory("/workspace", source).
        WithEnvVariable("ENABLE_CUDA", fmt.Sprintf("%t", enableCuda)).
        WithExec([]string{
            "/kaniko/executor",
            "--context=/workspace", 
            "--dockerfile=/workspace/Dockerfile",
            "--destination=" + imageTag,
            "--build-arg=ENABLE_CUDA=" + fmt.Sprintf("%t", enableCuda),
            "--build-arg=REGISTRY=" + registry,
        }), nil
}

// GetSource retrieves source code from Git repository
func (m *Build) GetSource(
    ctx context.Context,
    // Git repository URL
    repo string,
    // Git reference (branch, tag, or commit)
    // +default="main"
    ref string,
) *Directory {
    return dag.Git(repo, GitOptsRef(ref)).Tree()
}

// CompleteWorkflow runs the complete build pipeline
func (m *Build) CompleteWorkflow(
    ctx context.Context,
    repo string,
    registry string,
    repository string, 
    tag string,
    // +default="main"
    ref string,
    // +default=true
    enableCuda bool,
) (*Container, error) {
    
    // Get source from Git
    source := m.GetSource(ctx, repo, ref)
    
    // Build the image
    return m.BuildImage(ctx, source, registry, repository, tag, enableCuda)
}
```

### Complete Go Implementation (Docker-Free)
```go
// Enhanced Go implementation with full CUDA support
func (m *Build) CompleteWorkflow(
    ctx context.Context,
    repo string,
    registry string,
    repository string,
    tag string,
    ref string,
    enableCuda bool,
) (*Container, error) {
    
    // Get source from Git
    source := dag.Git(repo, GitOptsRef(ref)).Tree()
    
    // Build image tag
    imageTag := fmt.Sprintf("%s/%s:%s", registry, repository, tag)
    if !enableCuda {
        imageTag += "-cpu"
    }
    
    // Use Kaniko for Docker-free building
    return dag.Container().
        From("gcr.io/kaniko-project/executor:latest").
        WithMountedDirectory("/workspace", source).
        WithExec([]string{
            "/kaniko/executor",
            "--context=/workspace",
            "--dockerfile=/workspace/Dockerfile",
            "--destination=" + imageTag,
            "--build-arg=ENABLE_CUDA=" + fmt.Sprintf("%t", enableCuda),
            "--build-arg=REGISTRY=" + registry,
            "--insecure",
            "--insecure-registry=" + registry,
        }), nil
}
```

## 🔄 **Migration to Dagger**

### Phase 1: Dagger + Argo Integration (Docker-Free)
```yaml
# build-dagger.yaml - No Docker daemon required
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dagger-build-
spec:
  serviceAccountName: ci-service-account
  entrypoint: dagger-build
  arguments:
    parameters:
      - name: gitRepo
        value: "https://devops.ra.se/DataLab/Datalab/_git/coder-templates"
      - name: gitRevision
        value: "main"
      - name: registry
        value: "registry.ra.se:5002"
      - name: imageRepository
        value: "airiksarkivet/devenv"
      - name: imageTag
        value: "v13.6.0"
      - name: enableCuda
        value: "true"
  templates:
  - name: dagger-build
    container:
      image: dagger/dagger:latest
      command: [dagger]
      args: [
        "call", "complete-workflow",
        "--repo={{workflow.parameters.gitRepo}}",
        "--registry={{workflow.parameters.registry}}",
        "--repository={{workflow.parameters.imageRepository}}", 
        "--tag={{workflow.parameters.imageTag}}",
        "--ref={{workflow.parameters.gitRevision}}",
        "--enable-cuda={{workflow.parameters.enableCuda}}"
      ]
      # NO Docker socket mount needed - Kaniko handles building!
```

### Phase 2: Enhanced Dagger Pipeline
```go
// Advanced features
func (m *Build) BuildWithOptimizations(
    ctx context.Context,
    source *Directory,
    registry string,
    repository string,
    tag string,
    enableCuda bool,
) (*Container, error) {
    
    // Add caching and optimization
    cacheVolume := dag.CacheVolume("kaniko-cache")
    
    return dag.Container().
        From("gcr.io/kaniko-project/executor:latest").
        WithMountedDirectory("/workspace", source).
        WithMountedCache("/cache", cacheVolume).
        WithExec([]string{
            "/kaniko/executor",
            "--context=/workspace",
            "--dockerfile=/workspace/Dockerfile", 
            "--destination=" + imageTag,
            "--cache=true",
            "--cache-dir=/cache",
            "--compressed-caching=false",
        }), nil
}

// Multi-architecture builds
func (m *Build) BuildMultiArch(
    ctx context.Context,
    source *Directory,
    registry string,
    repository string,
    tag string,
) ([]*Container, error) {
    
    platforms := []string{"linux/amd64", "linux/arm64"}
    var builds []*Container
    
    for _, platform := range platforms {
        build := dag.Container().
            From("gcr.io/kaniko-project/executor:latest").
            WithMountedDirectory("/workspace", source).
            WithExec([]string{
                "/kaniko/executor",
                "--context=/workspace",
                "--dockerfile=/workspace/Dockerfile",
                "--destination=" + fmt.Sprintf("%s/%s:%s-%s", registry, repository, tag, platform),
                "--customPlatform=" + platform,
            })
        builds = append(builds, build)
    }
    
    return builds, nil
}
```

## 📊 **Dagger vs Current Approach Comparison**

| Aspect | Current (Argo + Parameters) | Dagger + Argo | Pure Dagger (K8s Engine) |
|--------|----------------------------|---------------|---------------------------|
| **Complexity** | High (YAML + Parameters) | Medium | **Very Low** |
| **Debugging** | Difficult | Good | **Excellent** |
| **Development Experience** | Poor (CI-only) | Limited | **Interactive** |
| **Local Testing** | Impossible | Limited | **Full** |
| **Version Control** | Parameter-based | Git-native | **Git-native** |
| **Type Safety** | None | Partial | **Full** |
| **Flexibility** | Limited | High | **Very High** |
| **Learning Curve** | Medium | Medium | **Low** |
| **Maintenance** | High | Medium | **Very Low** |
| **Setup Requirements** | Argo + Secrets | Argo + Dagger Engine | **Dagger Engine Only** |
| **Real-time Feedback** | None | Batch | **Interactive** |
| **Multi-user Support** | Complex | Complex | **Simple (Shared Engine)** |

## 🔧 **Implementation Steps**

### Step 1: Deploy Dagger Engine to Kubernetes (Cluster Admin)
```bash
# Install Dagger engine as DaemonSet via Helm
helm upgrade --install --namespace=dagger --create-namespace \
  dagger oci://registry.dagger.io/dagger-helm

# Verify deployment
kubectl get pods -n dagger
kubectl get daemonset -n dagger
```

### Step 2: Connect from Workspace (Any Developer)
```bash
# Get Dagger engine pod name
DAGGER_ENGINE_POD_NAME="$(kubectl get pod \
  --selector=name=dagger-dagger-helm-engine --namespace=dagger \
  --output=jsonpath='{.items[0].metadata.name}')"

# Set connection to Kubernetes engine
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://$DAGGER_ENGINE_POD_NAME?namespace=dagger"

# Verify connection
dagger version
```

### Step 3: Set up Dagger Module
```bash
# Initialize Dagger module in your project
mkdir dagger
cd dagger
dagger init --sdk=go --name=build
```

### Step 4: Implement Build Functions
```bash
# Add build functions to dagger/main.go
# (Use the Go implementation below)
```

### Step 5: Test Direct Execution
```bash
# Test the Dagger pipeline directly from workspace
dagger call complete-workflow \
  --repo="https://devops.ra.se/DataLab/Datalab/_git/coder-templates" \
  --registry="registry.ra.se:5002" \
  --repository="airiksarkivet/devenv" \
  --tag="test-v1.0" \
  --ref="main" \
  --enable-cuda=true
```

### Step 6: Replace Build Script (Optional)
```bash
# Update build.sh to use Dagger instead of Argo
USE_DAGGER=${USE_DAGGER:-true}  # Default to Dagger

if [ "$USE_DAGGER" = "true" ]; then
    # Direct Dagger execution - no Argo needed!
    dagger call complete-workflow \
      --repo="$GIT_REPO" \
      --registry="$REGISTRY" \
      --repository="$IMAGE_REPOSITORY" \
      --tag="$IMAGE_TAG" \
      --enable-cuda="$ENABLE_CUDA"
else
    # Fallback to Argo workflow
    argo submit build.yaml $KUBECONFIG_OPTION ...
fi
```

## 🎯 **Benefits of Pure Dagger Approach**

### Immediate Benefits
✅ **No Argo complexity** - Direct pipeline execution from workspace  
✅ **Real-time development** - Interactive builds with immediate feedback  
✅ **Shared infrastructure** - One engine serves multiple developers  
✅ **No parameter size limits** - Git repository handled natively  
✅ **Better error handling** - Programmatic control over build process  
✅ **Persistent cache** - Engine cache survives across sessions  

### Long-term Benefits
✅ **Pipeline as Code** - Version controlled, testable build logic  
✅ **Developer productivity** - Same tools for dev and production  
✅ **Infrastructure simplification** - Reduce CI/CD complexity  
✅ **Cross-platform** - Same pipeline works anywhere  
✅ **Composable** - Reusable functions across different projects  
✅ **Type safety** - Compile-time validation prevents runtime errors  

## 🚨 **Considerations and Challenges**

### Technical Challenges
- **Learning curve** - Team needs to learn Dagger concepts
- **Debugging** - New tooling for troubleshooting pipeline issues
- **Resource usage** - Dagger adds some overhead vs pure Kaniko
- **Integration complexity** - May require changes to existing tooling

### Migration Challenges  
- **Dual maintenance** - Both old and new systems during transition
- **Testing coverage** - Comprehensive testing of new pipeline approach
- **Team training** - Education on Dagger concepts and best practices
- **Tooling updates** - CI/CD tooling may need updates

## 🗺️ **Recommended Implementation Path**

### Phase 1: Dagger Engine Deployment (1 day)
1. **Deploy Dagger engine** to Kubernetes cluster (Cluster Admin)
2. **Verify engine accessibility** from workspace pods
3. **Configure connection credentials** and networking
4. **Test basic connectivity** with `dagger version`

### Phase 2: Development Setup (2 days)  
1. **Set up Dagger module** in project repository
2. **Implement build functions** with Kaniko integration
3. **Test from workspace** with development builds
4. **Validate Git integration** and authentication

### Phase 3: Production Validation (1 week)
1. **Run parallel builds** (Argo vs Dagger) for comparison
2. **Performance benchmarking** and optimization
3. **Team training** on direct Dagger usage
4. **Documentation** and best practices

### Phase 4: Migration and Simplification (1 week)
1. **Replace build.sh** with direct Dagger calls
2. **Remove Argo workflow complexity** (optional)
3. **Update CI/CD documentation** 
4. **Long-term monitoring** and maintenance setup

### Phase 5: Advanced Features (Ongoing)
1. **Multi-architecture builds** with parallel execution
2. **Advanced caching** strategies
3. **Custom Dagger modules** for team-specific workflows
4. **Integration** with other development tools

## 🌟 **Why Pure Dagger is the Optimal Solution**

The **Pure Dagger with Kubernetes Engine** approach represents a paradigm shift from traditional CI/CD:

### Traditional Approach Problems
- Complex Argo workflows with YAML configuration
- Parameter size limitations and security concerns  
- Difficult debugging and no local testing
- Separation between development and CI/CD environments

### Pure Dagger Solution
- **Developer-centric**: Same tools for development and production
- **Infrastructure-light**: One Helm chart replaces complex CI/CD setup
- **Real-time feedback**: Interactive builds with immediate results
- **Shared resources**: Efficient utilization of Kubernetes infrastructure

**This approach eliminates the artificial boundary between development and CI/CD, providing a unified build experience that scales from individual developers to production deployments!**