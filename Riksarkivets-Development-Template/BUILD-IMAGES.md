# Building v14.0.0 Images

The workspace configuration has been updated to use v14.0.0 images that include Go and Dagger pre-installed with automatic Kubernetes engine configuration.

## Required Images

To complete the upgrade, build these images using the new Dagger build system:

### CPU Version
```bash
# Build CPU-only version
export ENABLE_CUDA=false
export IMAGE_TAG=v14.0.0-cpu
./build-dagger.sh
```

### GPU Version  
```bash
# Build GPU-enabled version
export ENABLE_CUDA=true
export IMAGE_TAG=v14.0.0
./build-dagger.sh
```

## Benefits of v14.0.0

**New tools included:**
- Go programming language
- Dagger CI/CD engine

**Automatic configuration:**
- `_EXPERIMENTAL_DAGGER_RUNNER_HOST` set for Kubernetes engine
- Ready to use `./build-dagger.sh` immediately
- No manual setup required

**Enhanced capabilities:**
- Docker-free builds with Kaniko via Dagger
- Git-based source management (no dockerfileContent limits)
- Hybrid Go+Python development workflows

## Migration

Once images are built and available in the registry:
1. ✅ main.tf updated to use v14.0.0
2. ✅ build scripts updated to default to v14.0.0  
3. ⏳ Build and push v14.0.0-cpu image
4. ⏳ Build and push v14.0.0 image
5. ⏳ Test new workspace creation

## Usage

New workspaces will automatically have Dagger configured and can immediately use:
- `./build-dagger.sh` - Modern Dagger-based builds
- `./build.sh` - Legacy Argo workflow builds (for compatibility)

The dockerfile-repository-refactor problem is solved with the new Dagger-based approach!