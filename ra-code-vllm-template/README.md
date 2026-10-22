---
display_name: RA-CODE (vLLM)
description: GPU workspace with a local LLM served by vLLM and RA-CODE (OpenCode) preconfigured
icon: /emojis/1f999.png
tags: [kubernetes, gpu, llm, vllm, opencode]
---

# RA-CODE (vLLM)

The `gpu` template (Kubernetes Deployment, optional GPU, NFS home volume)
plus a local coding assistant — the vLLM sibling of the `ra-code` (Ollama)
template.

- **vLLM** runs as a sidecar container in the workspace pod, serving one
  HuggingFace model on `127.0.0.1:8000` (OpenAI-compatible). The image is the
  official multi-arch `vllm/vllm-openai` (x86 GPU nodes and the ARM GB10).
  Weights download from HuggingFace at every start into an `emptyDir` on the
  node's local disk (`/opt/llm/hf`), never onto the NFS home volume. First
  start of a big model can take 30+ minutes; the startup probe allows 40.
- **Model**: picked from a catalog (or any HF repo via *Other*) at workspace
  creation, changeable later. The catalog lives in `local.vllm_models` in
  `main.tf` with per-model serve flags (tool-call parser, reasoning parser,
  extra args) and a vision flag — vLLM does not advertise modalities, so the
  flag is what lets OpenCode accept image attachments.
- **Gated models** (marked `[gated]`: Mistral, and anything else HF returns
  401 for) need the *HuggingFace token* parameter — a token with the model's
  license accepted. It is passed to the vLLM container as `HF_TOKEN`.
  Parameter values are visible to template admins.
- **RA-CODE** is OpenCode, installed in `~/.local/bin` at a pinned version
  and launched as `ra-code` (terminal) or from the *RA-CODE* app, configured
  with only the local `vllm` provider: OpenCode's built-in free cloud
  models, self-update checks, session sharing and the hourly
  models.opencode.ai catalog fetch are disabled. The config is written
  before the server is ready, so it is correct from the start.
- **MCP servers**: the Riksarkivet MCP (`riksarkivet-ra-mcp.hf.space`) and
  the Archives Portal Europe MCP (`riksarkivet-ape-mcp.hf.space`) are
  enabled by default, as in the Ollama template.

## Differences from the Ollama template

- **Weights are full-precision**: BF16/FP8 safetensors are 2-4x larger than
  Ollama's Q4 GGUFs, so the same GPU tier runs smaller models. An A5000
  (24 GB) tops out at E4B-class; a 6000 Ada (48 GB) tops out around 30 GB
  weights; 120B-class models need the 6000 Blackwell (96 GB) or GB10
  (128 GB shared).
- **Per-model serve flags**: tool calling needs the right
  `--tool-call-parser` (and often `--reasoning-parser`) per family; these
  are catalog fields, verified end to end by `scripts/test_models.sh`.
- **Dropped from the Ollama catalog**: `qwen3.5:122b` (FP8 is ~122 GB,
  fits nowhere; gated), `nemotron-3-super:120b` (gated on HF, superseded by
  3.5 Super VL). `gemma4:26b` and `gemma4:31b` moved up a tier (BF16).
- **Memory parameter** is the vLLM container's RAM limit: on the GB10 the
  model lives in unified memory, so pick 96 GB for 120B-class models.

## Versions

`local.vllm_image` (vLLM v0.32.0, the version NVIDIA's Nemotron 3.5 Super
VL card specifies) and `local.opencode_version` pin both tools; bump them
together. Nemotron 3.5 Super VL carries extra serve args from its model
card (`--mamba-backend flashinfer`, memory utilization); the LiLiCorr
speculative drafter from the card is not configured.

## Model catalog

The dropdown follows the same rules as the Ollama template, adapted:

1. **Tool calling, verified end to end** through the vLLM OpenAI API by
   `scripts/test_models.sh` (agent tools via RA-CODE, plus an MCP call).
2. **Weights + KV fit a workspace GPU tier**, quantized variants allowed
   (FP8, MXFP4, NVFP4). Sizes in the catalog are safetensors sums from the
   HF API; `scripts/check_models.sh` re-verifies existence and size.
3. **Current**: newest generation of each family.
4. **Coverage**: vision and coding options where the tier allows.

## Verified results (2026-10-20, vLLM v0.32.0)

Every catalog model below passed the full `scripts/test_models.sh` battery —
direct tool call, vision (multimodal models), an RA-CODE agent task
(write + run a script), and an MCP call — on the tier listed:

| Model | Tier | Tools | Vision | Agent | MCP |
|---|---|---|---|---|---|
| google/gemma-4-E2B-it | A5000 + GB10 | ✅ | ✅ | ✅ | ✅ |
| google/gemma-4-E4B-it | A5000 + GB10 | ✅ | ✅ | ✅ | ✅ |
| openai/gpt-oss-20b | A5000 | ✅ | – | ✅ | ✅ |
| Qwen/Qwen3.5-9B | 6000 Ada | ✅ | – | ✅ | ✅ |
| google/gemma-4-12B-it | 6000 Ada | ✅ | ✅ | ✅ | ✅ |
| Qwen/Qwen3.8-27B-FP8 | 6000 Ada | ✅ | – | ✅ | ✅ |
| google/gemma-4-26B-A4B-it | 6000 Blackwell | ✅ | ✅ | ✅ | ✅ |
| openai/gpt-oss-120b | 6000 Blackwell | ✅ | – | ✅ | ✅ |
| Qwen/Qwen3.6-35B-A3B | GB10¹ | ✅ | – | ✅ | ✅ |
| zai-org/GLM-4.7-Flash | GB10 | ✅ | – | ✅ | ✅ |
| google/gemma-4-31B-it | GB10 | ✅ | ✅ | ✅ | ✅ |
| Qwen/Qwen3-Coder-Next-FP8 | GB10 | ✅ | – | ✅ | ✅ |
| nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4 | GB10 | ✅ | ✅ | ✅ | ✅ |
| mistralai/Ministral-3-14B-Instruct | untested | gated, needs HF token ||||
| mistralai/Devstral-Small-2-24B-Instruct | untested | gated, needs HF token ||||

¹ Weights + KV verified to fit the 6000 Blackwell; the full battery was run
on the GB10. Hybrid-Mamba models (Qwen3.8/3.6) need `--max-num-seqs 128`
(catalog `extra_args`) or CUDA-graph capture exceeds the Mamba cache.

## Logs

- Setup: the *RA-CODE (vLLM + OpenCode)* script log in the Coder UI
- vLLM server: the `vllm` container logs (`kubectl logs <pod> -c vllm`),
  including download progress and engine startup
