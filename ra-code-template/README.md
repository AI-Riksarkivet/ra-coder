---
display_name: RA-CODE
description: GPU workspace with a local LLM (Ollama) and RA-CODE (OpenCode) preconfigured
icon: /emojis/1f999.png
tags: [kubernetes, gpu, llm, ollama, opencode]
---

# RA-CODE

The `gpu` template (Kubernetes Deployment, optional GPU, NFS home volume)
plus a local coding assistant:

- **Ollama** runs inside the workspace on the selected GPU. An init container
  copies the binary and its CUDA libraries from the official multi-arch
  `ollama/ollama` image, so x86 GPU nodes and the ARM GB10 both work.
- **Model**: picked from a catalog (or any name from ollama.com/library) at
  workspace creation, changeable later. It is pulled at every start into an
  `emptyDir` on the node's local disk (`/opt/llm`), never onto the NFS home
  volume, so it downloads again after a restart.
- **RA-CODE** is OpenCode, installed in `~/.local/bin` at a pinned version
  and launched as `ra-code` (terminal) or from the *RA-CODE* app. It is
  configured with only the local `ollama` provider: OpenCode's built-in free
  cloud models, self-update checks, session sharing and the hourly
  models.opencode.ai catalog fetch are disabled. OpenCode sends no usage
  telemetry (its OpenTelemetry export only runs when an endpoint is set). The
  config is written before the model download starts, so it is correct even
  if RA-CODE is opened while the model is still being pulled.
- **MCP servers**: the Riksarkivet MCP (`riksarkivet-ra-mcp.hf.space`) and
  the Archives Portal Europe MCP (`riksarkivet-ape-mcp.hf.space`) are enabled
  by default. Both are public, so no credentials are involved. Setting
  `"enabled": false` on one in `~/.config/opencode/opencode.json` sticks
  across restarts.
- **Branding**: a small TUI plugin (`scripts/ra-code-branding.tsx`, installed
  to `~/.config/opencode/ra-code/` and registered in `tui.json`) replaces the
  OpenCode logo on the home screen with RA-CODE, and the `ra-code` launcher
  sets the terminal title to RA-CODE.

The context window (`OLLAMA_CONTEXT_LENGTH`) defaults to 64K, the minimum
OpenCode needs. Larger windows cost GPU memory on top of the model size shown
in the catalog.

## Versions

`local.ollama_image` and `local.opencode_version` in `main.tf` pin both tools;
bump them together. The model catalog lists download sizes from
registry.ollama.ai and which GPUs they fit (A5000 24 GB, 6000 Ada 48 GB,
6000 Blackwell 96 GB, GB10 128 GB shared).

## Logs

- Setup: the *RA-CODE (Ollama + OpenCode)* script log in the Coder UI
- Model download: `/opt/llm/pull.log`
- Server: `/opt/llm/serve.log`
