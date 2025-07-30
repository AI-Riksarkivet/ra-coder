# ML Workspace Template - Current Tools Overview

## Infrastructure and Container Platform

### Base System
- **OS:** Ubuntu 22.04 LTS (Jammy)
- **Container Runtime:** Docker with Kubernetes deployment
- **User:** `coder` (UID 1000) with sudo access
- **Architecture:** AMD64 with optional NVIDIA GPU support

### GPU Support
- **CUDA Version:** 12.2 (compatible with CUDA 12.1 applications like PyTorch)
- **GPU Types Supported:**
  - Quadro RTX 5000
  - NVIDIA RTX A5000
  - NVIDIA RTX A6000  
  - NVIDIA RTX 6000 Ada Generation
- **GPU Count:** Configurable 0-4 GPUs per workspace
- **Runtime:** NVIDIA Container Runtime for GPU workloads

## Development Environment

### Package Management
- **Homebrew:** `/home/linuxbrew/.linuxbrew` - Primary package manager
- **UV:** Python package installer and resolver
- **System APT:** For system-level packages

### Python Environment  
- **Python Version:** 3.12 (installed via Homebrew)
- **Virtual Environment:** `/opt/venv-py312` (auto-activated)
- **Package Manager:** UV for fast Python package management

### Core Development Tools
| Tool | Version/Source | Purpose |
|------|----------------|---------|
| `git` | System APT | Version control |
| `pre-commit` | Homebrew | Git hooks management |
| `ruff` | Homebrew | Python linting and formatting |
| `vim` | Homebrew | Text editor |
| `nano` | Homebrew | Simple text editor |
| `gh` | Homebrew | GitHub CLI integration |

## Machine Learning and Data Science Stack

### Core ML Framework
- **PyTorch:** 2.3.1 with CUDA 12.1 support
  - `torch`
  - `torchvision` 
  - `torchaudio`

### Data Science Libraries (Pre-installed in venv)
| Library | Purpose |
|---------|---------|
| `numpy` | Numerical computing |
| `pandas` | Data manipulation and analysis |
| `scikit-learn` | Machine learning algorithms |
| `matplotlib` | Data visualization |
| `transformers` | Hugging Face NLP models |
| `datasets` | Hugging Face datasets |
| `accelerate` | Hugging Face model acceleration |

### MLOps and Experiment Tracking
| Tool | Purpose | Configuration |
|------|---------|---------------|
| `mlflow` | Experiment tracking | Client library installed |
| `lakefs` | Data versioning | CLI with secret-based config |
| `argo` | Workflow orchestration | CLI for Kubernetes workflows |

## AI-Powered Development Tools

### Coding Assistants
| Tool | Purpose | Configuration |
|------|---------|---------------|
| **Aider** | Command-line AI coding assistant | Configured for local vLLM model |
| **Continue** | VS Code AI extension | Integrated with OpenHands model |
| **Claude Code** | Anthropic's coding assistant | Built-in via Coder module |

### AI Model Configuration
- **Local LLM Service:** `http://llm-service.models:8000/v1`
- **Model:** `all-hands/openhands-lm-32b-v0.1` (OpenHands LLM)
- **API Format:** OpenAI-compatible endpoint

## Cloud and Infrastructure Tools

### Kubernetes Ecosystem
| Tool | Purpose |
|------|---------|
| `kubectl` | Kubernetes CLI |
| `helm` | Kubernetes package manager |
| `k9s` | Kubernetes TUI management |

### Cloud CLIs
| Tool | Purpose | Status |
|------|---------|-------|
| `awscli` | AWS CLI | Installed |
| `azure-cli` | Azure CLI | Available but commented out |
| `google-cloud-sdk` | Google Cloud CLI | Available but commented out |

### Infrastructure as Code
| Tool | Purpose |
|------|---------|
| `terraform` | Infrastructure provisioning |

## Development IDE and Extensions

### VS Code Server (code-server)
- **Access:** Web-based IDE via Coder app
- **Port:** 13338 (internal)
- **Configuration:** No authentication, telemetry disabled

### Pre-installed VS Code Extensions
| Extension | Purpose |
|-----------|---------|
| `ms-python.python` | Python language support |
| `ms-python.debugpy` | Python debugging |
| `anthropic.claude-code` | Claude AI integration |

### Additional VS Code Extensions (from README)
- Ruff linter support
- Dockerfile linting (Hadolint)
- YAML support
- Git Graph visualization
- Material Icon Theme
- Continue AI assistant
- Marimo notebook support

## Data Processing and Storage

### Databases and Analytics
| Tool | Purpose |
|------|---------|
| `duckdb` | In-process analytical database |

### Data Versioning
- **LakeFS:** Git-like operations for data lakes
  - Configuration: `~/.lakectl.yaml`
  - Credentials: Mounted from Kubernetes secrets
  - Endpoint: `http://lakefs.lakefs:80/`

### Storage Mounts
| Mount Point | Source | Purpose |
|-------------|--------|---------|
| `/home/coder` | Kubernetes PVC | Persistent user home |
| `/mnt/scratch` | Host path | Temporary/scratch space |
| `/mnt/work` | Host path | Shared work directory |
| `/etc/secrets/lakefs` | Kubernetes secret | LakeFS credentials |

## Web Applications and File Management

### Coder Apps
| App | Purpose | Port |
|-----|---------|------|
| **VS Code Web** | Primary IDE | 13338 |
| **File Browser** | Web file manager | 13339 |
| **Claude Code** | AI coding interface | Managed by Coder |

### Additional Services
- **Dotfiles:** Personal configuration management
- **AgentAPI:** Internal Coder communication service

## Build and CI/CD System

### Container Build System
| Tool | Purpose | Configuration |
|------|---------|---------------|
| **Kaniko** | Kubernetes-native builds | Via Argo Workflows |
| **Docker** | Local development | Socket mount available |
| **Argo Workflows** | CI/CD pipeline execution | Integrated build system |

### Build Configuration
- **Registry:** `registry.ra.se:5002` (hardcoded)
- **Images:** Separate CUDA and CPU variants
- **Workflow TTL:** 3 hours auto-cleanup
- **Namespace:** `ci` for build operations

## Resource Management

### Configurable Resources
| Resource | Default | Options | Mutable |
|----------|---------|---------|---------|
| **CPU** | 2 cores | 2-24 cores | Yes |
| **Memory** | 2 GB | 2-96 GB | Yes |
| **Home Disk** | 10 GB | 1-99999 GB | No |
| **GPU Count** | 0 | 0-4 GPUs | No |

### Resource Monitoring
- CPU usage (container and host)
- Memory usage (container and host)  
- Disk usage (home directory)
- Load average (host)
- Metadata collection interval: 10-60 seconds

## Security and Access Control

### Authentication and Authorization
- **RBAC:** Limited Kubernetes permissions via service account
- **Secrets Management:** Kubernetes secrets for sensitive data
- **Container Security:** Non-root user execution

### Network Security
- **Registry Access:** Insecure mode for internal registry
- **Service Mesh:** No explicit service mesh configuration
- **Network Policies:** Not defined in template

## Configuration and Environment Variables

### Key Environment Variables
| Variable | Purpose | Source |
|----------|---------|--------|
| `CODER_AGENT_TOKEN` | Coder agent authentication | Auto-generated |
| `HOME` | User home directory | `/home/coder` |
| `LOGNAME` | User identification | Coder workspace owner |
| `KUBECONFIG` | Kubernetes config path | `/home/coder/.kube/config` |
| `MLFLOW_TRACKING_URI` | MLflow server URL | Optional parameter |
| `ARGO_BASE_HREF` | Argo Workflows UI | Optional parameter |

### Token Management
| Token Type | Environment Variable | Purpose |
|------------|---------------------|---------|
| **Anthropic API** | `CODER_MCP_CLAUDE_API_KEY` | Claude Code integration |
| **GitHub** | `GH_TOKEN` | GitHub API access |
| **Hugging Face** | `HF_TOKEN` | HF Hub access |

## Version Information

### Current Versions (as of analysis)
- **Template Version:** Not explicitly versioned
- **Container Image:** v13.4.0 (production), v13.3.0 (build), v9.0.0/v8.0.0 (docs)
- **Coder Modules:**
  - VS Code Web: 1.3.1
  - File Browser: 1.0.30
  - Dotfiles: 1.0.29
  - Claude Code: 2.0.3 (installing 1.0.62)

### Update Strategy
- **Image Updates:** Manual via build system
- **Module Updates:** Manual version bumps in Terraform
- **Tool Updates:** Via Homebrew/package managers during builds

## External Service Integrations

### Required External Services
| Service | Purpose | Endpoint |
|---------|---------|----------|
| **LLM Service** | AI model serving | `http://llm-service.models:8000/v1` |
| **LakeFS** | Data versioning | `http://lakefs.lakefs:80/` |
| **Container Registry** | Image storage | `registry.ra.se:5002` |

### Optional External Services  
| Service | Purpose | Configuration |
|---------|---------|---------------|
| **MLflow Tracking** | Experiment tracking | Via `mlflow_external_address` variable |
| **Argo Workflows UI** | Workflow management | Via `argowf_external_address` variable |

## Summary

This ML workspace template provides a comprehensive development environment optimized for:
- **GPU-accelerated machine learning** with PyTorch and CUDA 12.2
- **AI-assisted development** with multiple coding assistants
- **MLOps workflows** with experiment tracking and data versioning  
- **Kubernetes-native deployment** with flexible resource allocation
- **Modern development experience** with VS Code and productivity tools

The template is particularly well-suited for:
- Deep learning research and development
- Computer vision and NLP projects  
- MLOps and model deployment workflows
- Team-based ML development with shared infrastructure
- GPU-intensive computational workloads

**Strengths:** Comprehensive ML tooling, AI integration, GPU support, Kubernetes-native  
**Areas for Improvement:** Multi-framework support, enhanced security, better documentation, resource optimization