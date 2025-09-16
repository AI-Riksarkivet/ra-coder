# Riksarkivet Developer Template

Welcome to your AI-powered development workspace! This comprehensive guide will help you get started quickly and make the most of your development environment.

## 🚀 Quick Start for First-Time Users

### What is this?

This is a cloud-based development environment that provides:
- A full Ubuntu Linux workspace accessible through your browser
- Pre-installed development tools and programming languages
- AI coding assistance with Claude Code
- GPU support for machine learning (when enabled)
- Persistent storage for your code and data

### How to Access Your Workspace

Once your workspace is created, you can access it through:
1. **VS Code Web** - Click the VS Code button in your Coder dashboard for a full IDE experience
2. **Terminal** - Use the terminal button for direct command-line access
3. **File Browser** - Manage files through a web interface
4. **SSH** - Connect from your local machine using `coder ssh <workspace-name>`

### First Steps

1. **Check Your Environment**
   ```bash
   # See what tools are installed
   which python node go git dagger

   # Check versions
   python --version
   node --version

   # View available storage
   df -h /home/coder
   ```

2. **Set Up Git** (automatically configured from Coder profile)
   ```bash
   git config --global --list  # Your name and email are already set
   ```

3. **Start Coding with AI Assistance**
   ```bash
   # Claude Code is pre-installed
   claude --help

   # Use Claude for any coding task
   claude "help me write a Python script to process CSV files"
   ```

## 📚 Common Tasks & Workflows

### Working with Python
```bash
# Python 3.12 is pre-installed with virtual environment
python --version

# Install packages using uv (fast Python package installer)
uv pip install pandas numpy jupyter

# Or use pip directly
pip install requests beautifulsoup4

# Start Jupyter notebook
jupyter notebook --ip=0.0.0.0 --no-browser
```

### Working with Node.js/JavaScript
```bash
# Node v22 is installed via Homebrew
node --version
npm --version

# Create a new project
mkdir my-project && cd my-project
npm init -y

# Install packages
npm install express axios
```

### Using Dagger for Containerized Builds
```bash
# Dagger is preferred over Docker for builds
dagger version

# Initialize a Dagger project
dagger init

# Run Dagger functions
dagger call --help
```

### Working with AI Tools
```bash
# Claude Code for AI assistance
claude "explain this error: ..."
claude "refactor this function for better performance"

# Hugging Face CLI (when token is configured)
huggingface-cli whoami
huggingface-cli download meta-llama/Llama-2-7b-chat-hf
```

### Kubernetes & Cloud Development
```bash
# Kubectl is pre-configured
kubectl get pods
kubectl get nodes

# Use k9s for interactive Kubernetes management
k9s

# Helm for package management
helm list

# Argo for workflows
argo list
```

## 🛠️ Pre-installed Tools & Software

### Programming Languages
- **Python 3.12**: With virtual environment at `/opt/venv-py312`
- **Node.js v22**: Latest LTS via Homebrew
- **Go**: Latest stable version
- **Bash**: With Starship prompt for enhanced experience

### Development Tools
- **Version Control**: git, gh (GitHub CLI)
- **Container Tools**: Dagger (preferred), Docker CLI
- **Cloud CLIs**: AWS CLI, Azure CLI, kubectl, helm, terraform
- **AI/ML Tools**: Claude Code, Hugging Face CLI
- **Database**: DuckDB for analytics
- **Editor**: vim, nano, VS Code (web)

### Package Managers
- **APT**: System packages (Ubuntu)
- **Homebrew**: CLI tools and modern software
- **uv**: Fast Python package installer
- **npm**: Node.js packages

## 📁 Workspace Storage & Files

### Important Directories
```bash
/home/coder              # Your home directory (persistent)
/home/coder/.kube        # Kubernetes configuration
/mnt/scratch            # Temporary scratch space (if enabled)
/mnt/work               # Shared work directory (if enabled)
/opt/venv-py312         # Python virtual environment
/home/linuxbrew         # Homebrew installation
```

### File Management Tips
- Your home directory (`/home/coder`) persists between sessions
- Use scratch volumes (`/mnt/scratch`) for temporary large files
- The work volume (`/mnt/work`) is shared across workspaces

## ⚙️ Workspace Configuration

### Choosing Your Preset

When creating your workspace, select a preset based on your needs:

| Preset | CPU | RAM | Storage | GPUs | Best For |
|--------|-----|-----|---------|------|----------|
| **Small Development** | 2 | 4GB | 10GB | None | Quick tasks, testing, light coding |
| **Standard Development** | 8 | 32GB | 100GB | None | Full-stack development, builds |
| **Standard Data Science** | 8 | 32GB | 100GB | None | Data analysis, notebooks |
| **Intense ML Training** | 20 | 96GB | 500GB | 2x Ada | Deep learning, large models |

### Optional Features You Can Enable

- **Dagger Engine**: For containerized builds (recommended for production workflows)
- **Advanced Tools**: Enables API tokens for GitHub, Hugging Face, Docker registries
- **Custom AI Prompt**: Personalize Claude Code's behavior
- **GPU Support**: For machine learning and CUDA workloads

### Setting Up API Tokens (Optional)

If you enable "Advanced Tools", you can configure:
```bash
# These are stored securely and available as environment variables
echo $GITHUB_TOKEN         # For private repo access
echo $ANTHROPIC_API_KEY     # For Claude API
echo $HF_TOKEN             # For Hugging Face models
```

## 🔧 Troubleshooting Guide

### Common Issues & Solutions

#### Can't find a command/tool
```bash
# Check if it's installed via Homebrew
brew list | grep <tool-name>

# Install if missing
brew install <tool-name>

# Or use apt for system packages
sudo apt update && sudo apt install <package-name>
```

#### Python package installation issues
```bash
# Try using uv (faster and more reliable)
uv pip install <package>

# If that fails, use pip with --user flag
pip install --user <package>

# For system-wide installation
sudo pip install <package>
```

#### Out of storage space
```bash
# Check disk usage
df -h
du -sh /home/coder/* | sort -h

# Clean up pip cache
pip cache purge

# Clean up apt cache
sudo apt clean

# Remove unused Docker images (if Docker is enabled)
docker system prune -a
```

#### GPU not detected (when enabled)
```bash
# Check NVIDIA driver
nvidia-smi

# Check CUDA installation
nvcc --version

# Verify GPU is allocated to pod
kubectl describe pod $(hostname)
```

#### Can't connect to Kubernetes cluster
```bash
# Check kubeconfig
kubectl config view

# Test connection
kubectl cluster-info

# If using in-cluster auth, verify service account
kubectl auth can-i get pods
```

#### VS Code extensions not loading
```bash
# Restart VS Code server
pkill code-server
# Then refresh browser

# Check extension logs
cat ~/.local/share/code-server/logs/*
```

### Getting Help

- **Workspace logs**: Check the Coder dashboard for workspace logs
- **Container logs**: `kubectl logs $(hostname)`
- **System resources**: `htop` to monitor CPU/memory
- **Network issues**: `curl -I https://google.com` to test connectivity

## 📝 Tips & Best Practices

### Performance Optimization
- Use the smallest preset that meets your needs
- Close unused browser tabs (VS Code, terminals)
- Use `screen` or `tmux` for long-running processes
- Clean up temporary files regularly

### Data Management
- Keep large datasets in `/mnt/scratch` (when available)
- Use Git LFS for large files in repositories
- Compress unused data: `tar -czf archive.tar.gz folder/`

### Development Workflow
- Use Dagger instead of Docker for builds (more efficient)
- Leverage Claude Code for code reviews and refactoring
- Set up pre-commit hooks for code quality
- Use `direnv` for project-specific environment variables

### Security
- Never commit secrets to Git
- Use environment variables for API keys
- Keep sensitive data in Kubernetes secrets
- Regularly update your dependencies

## 🏗️ For Template Administrators

### Building and Deploying the Template

```bash
# Build and deploy CPU version
dagger call build-pipeline \
  --cluster-name="developer" \
  --source=./riksarkivet-developer-template \
  --docker-password=env:DOCKER_PASSWORD \
  --docker-username=airiksarkivet \
  --image-repository=riksarkivet/workspace-developer \
  --image-tag=v1.0.0 \
  --preset "Small Development" \
  --coder-url=http://coder.coder.svc.cluster.local \
  --coder-token=env:CODER_TOKEN \
  --template-name="RA-Developer-CPU" \
  --env-vars="ENABLE_CUDA=false"

# Build and deploy GPU version
dagger call build-pipeline \
  --cluster-name="developer" \
  --source=./riksarkivet-developer-template \
  --docker-password=env:DOCKER_PASSWORD \
  --docker-username=airiksarkivet \
  --image-repository=riksarkivet/workspace-developer \
  --image-tag=v1.0.0 \
  --preset "Small Development" \
  --coder-url=http://coder.coder.svc.cluster.local \
  --coder-token=env:CODER_TOKEN \
  --template-name="RA-Developer-GPU" \
  --env-vars="ENABLE_CUDA=true"
```

### Testing Locally
```bash
# Build and test image locally
dagger call build-local \
  --source="./" \
  --image-repository="riksarkivet/workspace-developer" \
  --env-vars="ENABLE_CUDA=false" \
  --image-tag="local-test" \
  terminal
```

### Customizing the Template

#### Adding New Software
```bash
# Add to Dockerfile for permanent installation
RUN apt-get update && apt-get install -y <package>

# Or install temporarily in your workspace
brew install <tool>         # For CLI tools
uv pip install <package>     # For Python packages
npm install -g <package>     # For Node.js tools
```

#### Modifying Template Settings

1. Edit `main.tf` for infrastructure changes
2. Update `Dockerfile` for base image modifications
3. Modify scripts in `scripts/` for startup customization
4. Rebuild and deploy using Dagger pipeline

## 📊 Monitoring Your Workspace

```bash
# Check resource usage
htop                        # Interactive process viewer
df -h                       # Disk usage
free -h                     # Memory usage

# GPU monitoring (when enabled)
nvidia-smi                  # GPU status and memory
watch -n 1 nvidia-smi       # Real-time GPU monitoring

# Kubernetes information
kubectl top pod $(hostname) # Pod resource usage
kubectl describe pod $(hostname) # Full pod details
```

## 🚀 Quick Command Reference

### Essential Commands
```bash
# Navigation & Files
cd ~                        # Go to home directory
ls -la                      # List all files
tree -L 2                   # Show directory tree

# Development
git status                  # Check repo status
dagger version              # Check Dagger
claude --help               # AI assistance

# Package Management
brew search <package>       # Find Homebrew packages
uv pip list                 # List Python packages
npm list -g --depth=0       # List global npm packages

# Process Management
screen -S mysession         # Start new screen session
screen -r mysession         # Reattach to session
jobs                        # List background jobs

# System
sudo systemctl status       # Check services
which <command>             # Find command location
env | grep -i <term>        # Search environment variables
```

## 🔗 Additional Resources

- **Workspace Claude Docs**: See `workspace-claude.md` for AI integration details
- **Argo Workflows**: Check `argo-workflows/` for CI/CD templates
- **Container Details**: Review `Dockerfile` for installed software
- **Infrastructure Code**: Examine `main.tf` for Terraform configuration

## 💡 Final Tips

1. **Start small**: Use the "Small Development" preset initially
2. **Save often**: Your home directory persists, but containers can restart
3. **Use Claude Code**: It's your AI pair programmer - use it liberally
4. **Monitor resources**: Keep an eye on disk and memory usage
5. **Ask for help**: Check logs and documentation when stuck

---

**Template Version**: Latest
**Base Image**: Ubuntu 22.04 LTS
**Maintained by**: Riksarkivet Development Team

For issues or improvements, please contact the template administrators or submit a pull request to the template repository.