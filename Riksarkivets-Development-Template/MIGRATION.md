# Migration Guide: Argo Workflows → Dagger Pipeline

This guide helps you migrate from the old Argo Workflows build system to the new Dagger + Kaniko pipeline.

## 🎯 Why Migrate?

### Problems with Old System (Argo Workflows)
❌ **Complex setup** - Required YAML workflows, service accounts, RBAC  
❌ **Size limitations** - 32KB limit on dockerfileContent parameter  
❌ **Hard to debug** - Required `kubectl logs` and Argo CLI  
❌ **Kubernetes overhead** - Full Job/Pod lifecycle for each build  
❌ **Dependency heavy** - Required Argo Workflows installation  

### Benefits of New System (Dagger)
✅ **Simple setup** - Single Go module, no YAML  
✅ **No size limits** - Direct Dockerfile reading  
✅ **Easy debugging** - Direct output, real-time logs  
✅ **Efficient execution** - Direct container execution  
✅ **Minimal dependencies** - Only Dagger engine required  
✅ **Same result** - Identical images, same Kaniko backend  

## 🔄 Command Migration

### Before: build.sh (Argo Workflows)
```bash
# Old command structure
./build.sh [ENABLE_CUDA] [SERVICE_NAME] [TAG] [REGISTRY]

# Examples
./build.sh true devenv v14.0.0 registry.ra.se:5002
./build.sh false devenv v14.0.0 registry.ra.se:5002
```

### After: Dagger Commands
```bash
# New command structure - Method 1 (Direct Dagger)
dagger call build-image \
  --dockerfile-content="$(cat Dockerfile)" \
  --enable-cuda=[true|false] \
  --service-name=[SERVICE_NAME] \
  --image-tag=[TAG] \
  --registry=[REGISTRY]

# New command structure - Method 2 (Shell script)  
./build-dagger.sh [ENABLE_CUDA] [SERVICE_NAME] [TAG] [REGISTRY]
```

## 📋 Migration Mapping

| Old Parameter | New Parameter | Notes |
|---------------|---------------|-------|
| `ENABLE_CUDA=true` | `--enable-cuda=true` | Same functionality |
| `ENABLE_CUDA=false` | `--enable-cuda=false` | Auto-adds `-cpu` suffix |
| `SERVICE_NAME=devenv` | `--service-name=devenv` | Used in image repository |
| `TAG=v14.0.0` | `--image-tag=v14.0.0` | Base tag before CUDA suffix |
| `REGISTRY=registry.ra.se:5002` | `--registry=registry.ra.se:5002` | Same registry |
| N/A | `--dockerfile-content="$(cat Dockerfile)"` | **New**: Direct file reading |

## 🚀 Step-by-Step Migration

### Step 1: Verify Prerequisites
```bash
# Check Dagger is working
dagger version
# Should show: dagger v0.18.14 (tcp://dagger-dagger-helm-engine...)

# Verify you're in correct directory
ls -la Dockerfile
# Should show your Dockerfile exists
```

### Step 2: Test New Build System
```bash
# Test with simple build first
dagger call hello
# Should return: "Dagger TCP Success - Build pipeline ready!"

# Test build command generation
dagger call get-dagger-build-command
# Should return the equivalent dagger command
```

### Step 3: Migrate Your Builds

#### Example 1: CUDA Build
```bash
# Old way
./build.sh true devenv v14.0.0 registry.ra.se:5002

# New way (choose one)
dagger call build-image --dockerfile-content="$(cat Dockerfile)" --enable-cuda=true --service-name=devenv --image-tag=v14.0.0 --registry=registry.ra.se:5002
# OR
./build-dagger.sh true devenv v14.0.0 registry.ra.se:5002
```

#### Example 2: CPU Build
```bash
# Old way
./build.sh false devenv v14.0.0 registry.ra.se:5002

# New way (choose one)
dagger call build-image --dockerfile-content="$(cat Dockerfile)" --enable-cuda=false --service-name=devenv --image-tag=v14.0.0 --registry=registry.ra.se:5002
# OR  
./build-dagger.sh false devenv v14.0.0 registry.ra.se:5002
```

### Step 4: Update CI/CD Scripts

#### Before: CI Script Using Argo
```bash
#!/bin/bash
# old-ci.sh
export ENABLE_CUDA=false
export SERVICE_NAME=devenv  
export TAG=v$(date +%Y%m%d)-$(git rev-parse --short HEAD)
export REGISTRY=registry.ra.se:5002

echo "Building with Argo Workflows..."
./build.sh $ENABLE_CUDA $SERVICE_NAME $TAG $REGISTRY

echo "Checking Argo workflow status..." 
argo list -n ci | grep kaniko-build
```

#### After: CI Script Using Dagger
```bash
#!/bin/bash  
# new-ci.sh
export ENABLE_CUDA=false
export SERVICE_NAME=devenv
export TAG=v$(date +%Y%m%d)-$(git rev-parse --short HEAD) 
export REGISTRY=registry.ra.se:5002

echo "Building with Dagger..."
dagger call build-image \
  --dockerfile-content="$(cat Dockerfile)" \
  --enable-cuda=$ENABLE_CUDA \
  --service-name=$SERVICE_NAME \
  --image-tag=$TAG \
  --registry=$REGISTRY

echo "✅ Build completed - no workflow tracking needed!"
```

## 🔍 Verification Steps

### 1. Compare Build Results
```bash
# Check that both methods produce same images
OLD_IMAGE="registry.ra.se:5002/airiksarkivet/devenv:v14.0.0-cpu"
NEW_IMAGE="registry.ra.se:5002/airiksarkivet/devenv:dagger-test-$(date +%s)-cpu"

# Build with new system
dagger call build-image --dockerfile-content="$(cat Dockerfile)" --enable-cuda=false --image-tag="dagger-test-$(date +%s)"

# Compare in registry
curl -k http://registry.ra.se:5002/v2/airiksarkivet/devenv/tags/list | jq .
```

### 2. Performance Comparison
```bash
# Time old build (if still available)
time ./build.sh false devenv test-old registry.ra.se:5002

# Time new build
time dagger call build-image --dockerfile-content="$(cat Dockerfile)" --enable-cuda=false --image-tag=test-new
```

### 3. Functionality Test
```bash
# Test that built images work the same
docker run --rm registry.ra.se:5002/airiksarkivet/devenv:test-new-cpu python --version
docker run --rm registry.ra.se:5002/airiksarkivet/devenv:test-old-cpu python --version
# Should show identical Python versions
```

## 📚 Migration Checklist

- [ ] **Dagger engine tested** - `dagger version` works
- [ ] **Basic build tested** - `dagger call hello` succeeds  
- [ ] **Sample build completed** - Built and pushed test image
- [ ] **CI/CD scripts updated** - Replaced `./build.sh` calls
- [ ] **Team notification** - Informed team of new build process
- [ ] **Documentation updated** - Updated README/wikis with new commands
- [ ] **Old system cleanup** - Can remove Argo Workflows (optional)

## 🛠️ Rollback Plan

If you need to temporarily rollback to the old system:

```bash
# Old system should still work (if Argo is available)
./build.sh false devenv v14.0.0 registry.ra.se:5002

# Check if Argo Workflows is still installed
kubectl get workflows -n ci
argo version
```

## 🎯 Common Migration Issues

### Issue 1: "Dockerfile too large for dockerfileContent"
**Old problem**: Argo had 32KB limit on dockerfileContent parameter  
**New solution**: Dagger reads files directly, no size limit

### Issue 2: "Cannot debug build failures"
**Old problem**: Had to use `kubectl logs` and `argo logs`  
**New solution**: Direct output from dagger command shows all details

### Issue 3: "Build process too complex"
**Old problem**: Required understanding of Kubernetes, Argo, YAML  
**New solution**: Simple function calls, clear parameters

### Issue 4: "Takes too long to troubleshoot"
**Old problem**: Build failures required K8s debugging  
**New solution**: Immediate feedback, standard error messages

## 🚀 Next Steps After Migration

1. **Remove old dependencies** (optional):
   ```bash
   # Can remove if no other Argo usage
   # helm uninstall argo-workflows -n argo
   ```

2. **Update documentation**:
   - Update team wikis with new build commands
   - Add BUILD.md to project documentation
   - Update CI/CD pipeline documentation

3. **Optimize builds**:
   - Use `build-cuda` and `build-cpu` shortcuts
   - Create custom build scripts for your workflow
   - Set up automated builds with version tagging

---

**Migration complete!** You now have a simpler, more reliable build system that produces identical results with better developer experience. 🎉