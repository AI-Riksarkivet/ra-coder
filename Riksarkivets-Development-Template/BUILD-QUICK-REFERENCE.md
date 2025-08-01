# Build Quick Reference - Dagger Pipeline

## 🚀 Most Common Commands

```bash
# CUDA build (production)
dagger call build-cuda --dockerfile-content="$(cat Dockerfile)"

# CPU build (development)  
dagger call build-cpu --dockerfile-content="$(cat Dockerfile)"

# Custom version
dagger call build-image --dockerfile-content="$(cat Dockerfile)" --image-tag=v15.0.0
```

## 📋 Parameter Quick Reference

| Short Flag | Long Parameter | Default | Example |
|------------|----------------|---------|---------|
| N/A | `--dockerfile-content` | Required | `"$(cat Dockerfile)"` |
| N/A | `--enable-cuda` | `true` | `true` / `false` |
| N/A | `--image-tag` | `v14.0.0` | `v15.0.0` |
| N/A | `--service-name` | `devenv` | `ml-workbench` |
| N/A | `--registry` | `registry.ra.se:5002` | `registry.ra.se:5002` |

## 🔄 Migration Cheat Sheet

| Old Command | New Command |
|-------------|-------------|
|`./build.sh true devenv v14.0.0`|`dagger call build-cuda --dockerfile-content="$(cat Dockerfile)"`|
|`./build.sh false devenv v14.0.0`|`dagger call build-cpu --dockerfile-content="$(cat Dockerfile)"`|
|`./build.sh false devenv v15.0.0`|`dagger call build-image --dockerfile-content="$(cat Dockerfile)" --enable-cuda=false --image-tag=v15.0.0`|

## 🏷️ Image Naming

| CUDA | Tag Input | Final Image |
|------|-----------|-------------|
| `true` | `v14.0.0` | `registry.ra.se:5002/airiksarkivet/devenv:v14.0.0` |
| `false` | `v14.0.0` | `registry.ra.se:5002/airiksarkivet/devenv:v14.0.0-cpu` |

## 🛠️ Troubleshooting

```bash
# Test connection
dagger version

# Test basic functionality  
dagger call hello

# Generate command without running
dagger call get-dagger-build-command --enable-cuda=false

# Check registry
curl -k http://registry.ra.se:5002/v2/airiksarkivet/devenv/tags/list
```

## 💡 Pro Tips

```bash
# Save time with shortcuts
alias dcuda='dagger call build-cuda --dockerfile-content="$(cat Dockerfile)"'
alias dcpu='dagger call build-cpu --dockerfile-content="$(cat Dockerfile)"'

# Version with git hash
TAG="v14.0.0-$(git rev-parse --short HEAD)"
dagger call build-image --dockerfile-content="$(cat Dockerfile)" --image-tag="$TAG"

# Build both variants
dagger call build-cuda --dockerfile-content="$(cat Dockerfile)" && \
dagger call build-cpu --dockerfile-content="$(cat Dockerfile)"
```

---
**Remember**: Always run from directory containing `Dockerfile` 📁