# Build Quick Reference - Git-Based Dagger Pipeline

## 🚀 Most Common Commands

```bash
# CUDA build (production) - SSH key auto-detected
dagger call build-cuda --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"

# CPU build (development)  
dagger call build-cpu --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"

# Custom version from Git
dagger call build-from-git --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates" --image-tag=v15.0.0
```

## 🔑 Key Changes

- **🚫 No Caching**: Kaniko caching disabled for reliability
- **📁 Git-Based**: All builds use Git repository as source
- **🔐 Auto SSH**: SSH key automatically detected from `~/.ssh/id_rsa`
- **⚡ Simplified**: Primary function `build-from-git` with shortcuts

## 📋 Parameter Quick Reference

| Short Flag | Long Parameter | Default | Example |
|------------|----------------|---------|---------|
| N/A | `--git-repo` | Required | `ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates` |
| N/A | `--git-ref` | `main` | `main` / `feature/branch` / `v14.1.1` |
| N/A | `--ssh-private-key` | Auto-detected `~/.ssh/id_rsa` | `"$(cat ~/.ssh/custom_key)"` |
| N/A | `--enable-cuda` | `true` | `true` / `false` |
| N/A | `--image-tag` | `v14.1.1` | `v15.0.0` |
| N/A | `--registry` | `registry.ra.se:5002` | `registry.ra.se:5002` |
| N/A | `--verbosity` | `info` | `debug` / `warn` |

## 🔄 Migration Cheat Sheet

| Old Command | New Command |
|-------------|-------------|
|`./build.sh true devenv v14.1.1`|`dagger call build-cuda --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"`|
|`./build.sh false devenv v14.1.1`|`dagger call build-cpu --git-repo="ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"`|
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