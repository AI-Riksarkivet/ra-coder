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
bump them together.

## Model catalog

The dropdown is chosen by these rules, not by taste:

1. **Tool calling, verified** from the registry: the chat template handles
   `.Tools` or the model uses one of Ollama's built-in renderers. RA-CODE is
   an agent; without tool calls it cannot edit files or use the MCP servers.
2. **Local weights that fit a workspace GPU**: about 19 GB for an A5000
   (24 GB), 40 GB for a 6000 Ada (48 GB), 85 GB for a 6000 Blackwell (96 GB),
   more on the GB10 (128 GB shared).
3. **Current**: updated within 12 months, newest generation of each family.
4. **Adopted**: at least 1M pulls on ollama.com.
5. **Coverage**: vision and coding options on every GPU tier, plus one small
   model for CPU-only workspaces.

`scripts/check_models.sh` checks every catalog entry against
registry.ollama.ai (tag exists, size, tool support) and exits non-zero on a
failure. Any other model can still be used through the *Other* option.

## Logs

- Setup: the *RA-CODE (Ollama + OpenCode)* script log in the Coder UI
- Model download: `/opt/llm/pull.log`
- Server: `/opt/llm/serve.log`
