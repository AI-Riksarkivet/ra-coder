# Riksarkivet Developer Template v2

A minimal, modern Coder workspace template for Kubernetes, based on the
official Coder Kubernetes starter template. It is the successor to the legacy
[`riksarkivet-developer-template`](../riksarkivet-developer-template), trimmed
down to the essentials and updated to current Coder registry modules.

## What's included

- **Base image**: `codercom/example-base:ubuntu` (no custom Dockerfile required)
- **Apps** (Coder registry modules):
  - [claude-code](https://registry.coder.com/modules/claude-code) v5.2.0 — Claude Code AI assistant
  - [vscode-web](https://registry.coder.com/modules/vscode-web) v1.5.0 — VS Code in the browser
  - [zed](https://registry.coder.com/modules/zed) v1.1.4 — Zed editor integration
  - [git-config](https://registry.coder.com/modules/git-config) v1.0.33
  - [git-commit-signing](https://registry.coder.com/modules/git-commit-signing) v1.0.32
  - [dotfiles](https://registry.coder.com/modules/dotfiles) v1.4.2
  - [filebrowser](https://registry.coder.com/modules/filebrowser) v1.1.5
- **Persistent storage**: home directory on a PVC (`nfs-client` storage class)
- **Optional GPU**: select a GPU type (Quadro RTX 5000 / RTX A5000 / RTX 6000 Ada)
  at workspace creation; the pod is pinned to matching GPU nodes and gets
  `nvidia` runtime + GPU resource limits

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cpu` | CPU cores (2/4/6/8) | 2 |
| `memory` | Memory in GB (2/4/6/8) | 2 |
| `home_disk_size` | Home disk size in GB (immutable) | 10 |
| `gpu_type` | GPU model or `None` (immutable) | None |
| `gpu_count` | Number of Ada GPUs (only for RTX 6000 Ada) | 1 |

## Template variables

| Variable | Description | Default |
|----------|-------------|---------|
| `use_kubeconfig` | Use host `~/.kube/config` instead of in-cluster auth | `false` |
| `namespace` | Kubernetes namespace for workspaces | `coder` |
| `claude_code_oauth_token` | OAuth token for Claude Code (`claude setup-token`) | `""` (sensitive) |

## Deploy

```bash
# Login (once)
coder login https://coder.ra.se

# Push a new version of the template
coder templates push riksarkivet-developer-v2 \
  --directory ./riksarkivet-developer-template-v2 \
  --message "describe your change" -y
```

## Differences from the legacy template

Dropped (for simplicity — see git history of the legacy template if needed):

- Workspace presets (Small/Standard/Intense ML)
- Dagger engine sidecar
- MLflow / Argo Workflows / LakeFS integrations
- Custom setup scripts (starship, ssh, coder CLI, agents config)
- Custom container image build (`riksarkivet/workspace-developer`)
- Scratch/work host-path volume mounts and CI mode
