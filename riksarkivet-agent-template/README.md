# Riksarkivet Agent Template

A flexible Coder template designed for running AI agents and automated workflows, providing a lightweight environment with essential tools for agent development, testing, and deployment.

## Overview

This template creates a minimal workspace optimized for:

- **Git-based Agent Deployment**: Automatically clone and run agents from Git repositories
- **AI Agent Development**: Build and test intelligent agents with Claude Code integration
- **Automated Workflows**: Run scripts and automation tasks
- **Quick Prototyping**: Rapidly develop and test agent-based solutions
- **API Integration**: Connect to various services and APIs for agent operations
- **Lightweight Footprint**: Minimal resource consumption for efficient agent execution

## Features

### Git Repository Integration

- **Automatic Clone**: Specify a Git repository URL to automatically clone agent code
- **Branch/Tag Support**: Choose specific branches, tags, or commits to deploy
- **Submodule Support**: Automatically initializes Git submodules if present
- **Private Repo Access**: Uses GitHub token for private repository authentication

### AI Agent Capabilities

- **Claude Code Integration**: Built-in AI assistant for agent development
- **Custom AI Prompts**: Configure agent behavior through workspace parameters
- **API Token Management**: Secure storage for Anthropic, GitHub, and Hugging Face tokens
- **Script Automation**: Execute Python, Bash, and Node.js agent scripts

### Development Environment

- **Multiple Runtimes**: Python 3.12, Node.js 22, Go for diverse agent implementations
- **Package Managers**: Homebrew, pip/uv, npm for dependency management
- **Version Control**: Git with automatic configuration
- **Essential Tools**: curl, wget, jq, ripgrep for data processing

### Lightweight Infrastructure

- **Base OS**: Ubuntu 22.04 with minimal footprint
- **Shell**: Bash with Starship prompt for enhanced developer experience
- **Persistent Storage**: Home directory for agent scripts and data
- **Web Access**: Code Server and File Browser for remote development

### Web Interfaces

- **Code Server**: Browser-based IDE for editing scripts and configurations
- **File Browser**: Web UI for navigating cluster logs and outputs
- **Web Terminal**: Direct shell access for kubectl commands
- **Claude Code**: AI assistant for troubleshooting cluster issues

## Prerequisites

Before using this template, ensure you have:

1. **Coder Server**: A Coder v2 instance deployed and accessible
2. **Kubernetes Cluster**:
   - Accessible by the Coder deployment
   - Sufficient resources for workspace containers

3. **Container Registry**: Access to the specified container image
4. **Kubernetes Namespace**: The target namespace must exist (default: `coder`)

## Workspace Parameters

Configure your workspace at creation time:

### Repository Configuration

- **Agent Repository URL**: Git repository containing your agent code
- **Git Branch/Tag**: Specific branch, tag, or commit to checkout (default: main)
- **Agent Working Directory**: Directory name for the cloned repository (default: agent)

### Resource Allocation

- **CPU Cores**: 1-36 cores (default: 4, suitable for most agents)
- **Memory**: 3-180 GB RAM (default: 8 GB, increase for memory-intensive agents)
- **Home Disk**: 5-1000 GB persistent storage (default: 20 GB for scripts and data)
- **Shared Memory**: 0-80% of RAM for `/dev/shm` (default: 20%)

### Agent Task Configuration

- **Agent Task Instructions**: Complete task prompt for what the agent should do
- **Auto-execute Agent on Startup**: Automatically run the agent task when workspace starts and stop workspace when complete

### Agent Configuration

- **Advanced Tools**: Enable API tokens for external service integration
   - Anthropic API key for Claude-powered agents (required for auto-execution)
   - GitHub token for repository operations (also used for private repo cloning)
   - Hugging Face token for model access
   - SSH keys for secure Git operations

## Template Variables

These variables are automatically set by the Dagger build pipeline:

| Variable | Description | Example |
|----------|-------------|---------|
| `image_registry` | Container registry URL | `"docker.io"` |
| `image_repository` | Container image repository | `"riksarkivet/workspace-agent"` |
| `image_tag` | Container image tag | `"v1.0.0"` |
| `use_kubeconfig` | Use host kubeconfig vs in-cluster auth | `false` |
| `namespace` | Kubernetes namespace for workspaces | `"coder"` |

## Getting Started

### 1. Build and Deploy with Dagger

Use the Dagger pipeline to build and deploy the template:

```bash
# Create a Coder API token
coder tokens create --name "dagger-deployment" --lifetime 24h

# Set environment variables
export DOCKER_PASSWORD="your-docker-hub-password"
export CODER_TOKEN="your-coder-api-token"  # Use the token from above

# Build and deploy the agent template
dagger call build-pipeline \
  --cluster-name="agent-cpu" \
  --source=./riksarkivet-agent-template \
  --docker-password=env:DOCKER_PASSWORD \
  --docker-username=airiksarkivet \
  --image-repository=riksarkivet/workspace-agent \
  --image-tag=v1.0.0 \
  --preset "Simple Development" \
  --coder-url=http://coder.coder.svc.cluster.local \
  --coder-token=env:CODER_TOKEN \
  --template-name="RA-Agent-CPU" \
  --template-params "AI Prompt=You are an intelligent agent assistant" \
  --env-vars="ENABLE_CUDA=false"

coder create \
  --template RA-Agent-CPU test-debug-workspace \
  --parameter "cpu=4" \
  --parameter "memory=8" \
  --parameter "home_disk_size=20" \
  --parameter "shared_memory_percentage=20" \
  --parameter "enable_advanced_tools=true" \
  --parameter "agent_git_repo=https://github.com/AI-Riksarkivet/coder-templates" \
  --parameter "agent_git_branch=main" \
  --parameter "agent_work_dir=agent" \
  --parameter "agent_auto_run=true" \
  --parameter "anthropic_api_key=...." \
  --parameter "gh_token=...." \
  --parameter "AI Prompt=Debug test: Run pwd and echo hello world"
  

dagger call build-pipeline \
  --cluster-name="agent-gpu" \
  --source=./riksarkivet-agent-template \
  --docker-password=env:DOCKER_PASSWORD \
  --docker-username=airiksarkivet \
  --image-repository=riksarkivet/workspace-agent \
  --image-tag=v1.0.0 \
  --preset "Simple Development" \
  --coder-url=http://coder.coder.svc.cluster.local \
  --coder-token=env:CODER_TOKEN \
  --template-name="RA-Agent-GPU" \
  --template-params "AI Prompt=You are an intelligent agent assistant" \
  --env-vars="ENABLE_CUDA=true"
```

### 2. Create Agent Workspace

Once deployed, create a workspace with your agent repository and task:

```bash
# Create workspace with automatic agent execution
coder create cluster-check-agent \
  --template riksarkivet-agent \
  --parameter agent_git_repo="https://github.com/your-org/k8s-agents" \
  --parameter agent_git_branch="main" \
  --parameter agent_work_dir="agents" \
  --parameter agent_task_prompt="Run python k8s_cluster_investigator_v2.py to check cluster state. Analyze the results and identify any issues or anomalies. Then use slackme -c ml-team -m 'summary' to notify the team with your findings and recommendations." \
  --parameter enable_advanced_tools=true \
  --parameter anthropic_api_key="sk-ant-api03-..." \
  --parameter cpu=4 \
  --parameter memory=8 \
  --parameter home_disk_size=20
```

The workspace will:

1. Clone the repository to `/home/coder/agents`
2. Automatically execute the agent task using Claude Code
3. Stop the workspace when the task is complete

## Agent Task Prompt Examples

### Cluster Health Check Agent

```sh
Run python k8s_cluster_investigator_v2.py to check cluster state. 
Analyze the results and identify any issues or anomalies. 
Then use slackme -c ml-team -m 'summary' to notify the team with your findings and recommendations.
```

### Data Pipeline Monitor

```sh
Execute bash check_pipeline.sh to verify data pipeline status. 
Review logs for any errors or performance issues. 
Generate a summary report and send it to the data-team Slack channel using slackme -c data-team -m 'report'.
```

### Security Audit Agent

```sh
Run python security_scan.py --full to perform security audit. 
Analyze vulnerabilities and compliance issues. 
Create a detailed report and notify security team via slackme -c security -m 'audit-complete: {summary}'.
```

### 3. Repository Requirements

Your agent repository can have any structure - Claude Code will intelligently navigate and execute based on your task prompt. The only requirement is that all dependencies are pre-installed in the Docker image.

**Common patterns**:

- Python scripts: `python script_name.py`
- Shell scripts: `bash script_name.sh`
- Multiple tools: Claude Code can run sequences of commands
- Configuration files: `.env.example` will be copied to `.env` if present

### 4. Agent Execution

With auto-run enabled (default), the agent will execute automatically:

1. Workspace starts and repository clones
2. Claude Code executes the agent task prompt
3. Agent analyzes, runs scripts, and reports results
4. Workspace automatically stops when complete

For manual execution or debugging, disable auto-run and use:

```bash
claude-code "Your agent task instructions here"
```

## Workspace Preset

### Simple Development (Default)

- **Purpose**: Agent development and automated workflow execution
- **Resources**: 4 CPU, 8GB RAM, 20GB storage
- **Features**: Minimal footprint, fast startup, AI integration
- **Use Cases**:
   - AI agent prototyping
   - Automation script development
   - API integration testing
   - Lightweight data processing

This template is optimized for agent workloads with adjustable resources based on your specific agent requirements.

## Volume Configuration

### Mounted Volumes

- **Home Directory**: `/home/coder` - Persistent storage for agent scripts and data
- **Shared Memory**: `/dev/shm` - Temporary memory-backed storage for inter-process communication
- **Kubeconfig**: `/home/coder/.kube/config` - Optional cluster access if needed

### Security Context

- Runs as non-root user (UID 1000) for security
- Secure environment variable injection for API tokens
- Isolated workspace with controlled resource limits

## Common Agent Repository Patterns

### Private Repository Access

For private repositories, enable "Advanced Tools" and provide a GitHub token:

```bash
coder create private-agent \
  --template riksarkivet-agent \
  --parameter agent_git_repo="https://github.com/your-org/private-agent" \
  --parameter enable_advanced_tools=true \
  --parameter gh_token="ghp_your_token_here"
```

### Using Specific Versions

Deploy a specific version of your agent:

```bash
# Using a tag
coder create stable-agent \
  --template riksarkivet-agent \
  --parameter agent_git_repo="https://github.com/your-org/agent" \
  --parameter agent_git_branch="v1.2.3"

# Using a commit hash
coder create test-agent \
  --template riksarkivet-agent \
  --parameter agent_git_repo="https://github.com/your-org/agent" \
  --parameter agent_git_branch="abc123def"
```

## Use Cases

This template supports any agent workflow where Claude Code can analyze, execute scripts, and report results:

- **Infrastructure Monitoring**: Cluster health checks, resource monitoring, alerting
- **Data Pipeline Automation**: ETL validation, data quality checks, pipeline monitoring
- **Security Auditing**: Vulnerability scans, compliance checks, security reporting
- **CI/CD Integration**: Build validation, test execution, deployment verification
- **Research & Analysis**: Data analysis, report generation, insight extraction

## Workspace Metadata

The template provides real-time agent environment information:

### Container Metrics

- CPU and memory usage for agent processes
- Host node resource utilization
- Load average for performance monitoring

### Environment Information

- Agent workspace configuration
- Available API tokens and credentials
- Network connectivity status
- Storage usage for agent data

## Security Features

- **Non-root Execution**: Container runs as user `coder` (UID 1000)
- **Secret Management**: API tokens stored securely in Kubernetes secrets
- **Network Isolation**: Pod-level network policies
- **SSH Key Management**: Secure handling of private keys for Git access
- **Registry Authentication**: Support for private container registries

## Troubleshooting

### Common Issues

**Agent API access fails**:

- Verify API tokens are correctly set in workspace parameters
- Enable "Advanced Tools" to access token configuration
- Check environment variables: `env | grep -E '(API|TOKEN)'`

**Python agent import errors**:

- Install required packages: `uv add anthropic pandas requests`
- Use virtual environment: `source /opt/venv-py312/bin/activate`
- Check Python path: `which python3`

**Insufficient resources for agent**:

- Increase CPU/memory if agent is compute-intensive
- Monitor usage: `htop` or check Coder dashboard metrics
- Consider using background tasks for long-running agents

### Getting Help

- **Agent Development**: Use Claude Code for AI-assisted coding
- **API Integration**: Check token configuration and network access
- **Performance**: Monitor agent resource usage via Coder dashboard
- **Template Issues**: Review container logs and workspace events

## Version Information

**Template Components**:

- **Base Image**: `riksarkivet/workspace-agent:latest`
- **Terraform Providers**: Coder >=2.4.0, Kubernetes provider
- **Language Runtimes**: Python 3.12, Node.js 22, Go latest
- **Claude Code**: v2.0.3 module for AI assistance
- **Package Managers**: Homebrew, pip/uv, npm

## Related Documentation

- **Main Repository**: `../README.md` - Build system and Dagger pipeline
- **Developer Template**: Full-featured development environment
- **Dagger Pipeline**: Automated build and deployment system