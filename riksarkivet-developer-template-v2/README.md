# Riksarkivet Developer Template v2

A minimal, modern Coder workspace template for Kubernetes, based on the
official Coder Kubernetes starter template. It is the successor to the legacy
[`riksarkivet-developer-template`](../riksarkivet-developer-template), trimmed
down to the essentials and updated to current Coder registry modules.

## What's included

- **Base image**: `codercom/example-base:ubuntu` (no custom Dockerfile required)
- **Deterministic toolset via Nix**: a single-user Nix install with the template's
  [`flake.nix`](flake.nix) provides the dev tools (git, gh, kubectl, helm, k9s,
  argo, terraform, python312+uv, nodejs 22, go, starship, awscli2, azure-cli, ...).
  The `/nix` store lives on the home PVC, so tools survive pod restarts.
  Edit `flake.nix` and push a new template version to change the toolset for
  everyone; inside a workspace, run `nix profile upgrade ~/devshell` or use
  `nix develop ~/devshell` for an ephemeral shell.
- **Apps** (Coder registry modules):
  - [claude-code](https://registry.coder.com/modules/claude-code) v5.2.0 — Claude Code AI assistant
  - [vscode-web](https://registry.coder.com/modules/vscode-web) v1.5.0 — VS Code in the browser
  - [zed](https://registry.coder.com/modules/zed) v1.1.4 — Zed editor integration
  - [git-config](https://registry.coder.com/modules/git-config) v1.0.33
  - [git-commit-signing](https://registry.coder.com/modules/git-commit-signing) v1.0.32
  - [dotfiles](https://registry.coder.com/modules/dotfiles) v1.4.2 (defaults to the [AI-Riksarkivet dotfiles](https://github.com/AI-Riksarkivet/dotfiles))
  - [filebrowser](https://registry.coder.com/modules/filebrowser) v1.1.5
  - [coder-login](https://registry.coder.com/modules/coder-login) v1.1.1 — pre-authenticated Coder CLI in the workspace
- **Workspace presets**: Small Development, Standard Development, Standard Data Science, Intense ML Training
- **Persistent storage**: home directory on a PVC (`nfs-client` storage class)
- **Shared memory**: configurable `/dev/shm` (percentage of RAM) for ML/data workloads
- **Optional GPU**: select a GPU type (Quadro RTX 5000 / RTX A5000 / RTX 6000 Ada)
  at workspace creation; the pod is pinned to matching GPU nodes and gets
  `nvidia` runtime + GPU resource limits
- **Advanced tools** (opt-in): `GH_TOKEN` / `HF_TOKEN` env vars and SSH key setup for git-over-SSH

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cpu` | CPU cores (slider, 1–36) | 4 |
| `memory` | Memory in GB (slider, 3–180) | 16 |
| `home_disk_size` | Home disk size in GB (immutable) | 10 |
| `shared_memory_percentage` | % of RAM for `/dev/shm` (0–80) | 20 |
| `gpu_type` | GPU model or `None` (immutable) | None |
| `gpu_count` | Number of Ada GPUs (only for RTX 6000 Ada) | 1 |
| `enable_advanced_tools` | Reveal token/SSH parameters | false |
| `gh_token` | GitHub personal access token (advanced) | `""` |
| `hf_token` | Hugging Face token (advanced) | `""` |
| `ssh_private_key` | SSH key for git access (advanced) | `""` |

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

- Dagger engine sidecar
- MLflow / Argo Workflows / LakeFS integrations
- Custom setup scripts (starship, coder CLI, agents/Continue config)
- Custom container image build (`riksarkivet/workspace-developer`)
- Scratch/work host-path volume mounts and CI mode

Kept from the legacy template: workspace presets, slider-based CPU/memory,
shared memory allocation, GPU support, advanced tool tokens, SSH key setup.
