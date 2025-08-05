#!/bin/bash

# generate-claude-md.sh - Generate system-wide CLAUDE.md configuration
# This script analyzes the system environment and creates a comprehensive CLAUDE.md file

OUTPUT_FILE="$HOME/CLAUDE.md"

# Function to get system information
get_system_info() {
    local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    local kernel=$(uname -r)
    local arch=$(uname -m)
    local user=$(whoami)
    local uid=$(id -u)
    echo "- **Platform**: Linux $os_info on kernel $kernel"
    echo "- **Architecture**: $arch"
    echo "- **User**: $user (UID $uid)"
    echo "- **Home Directory**: $HOME"
    echo "- **Workspace Type**: Coder v2 Kubernetes workspace"
    
    # Check for GPU
    if nvidia-smi &>/dev/null; then
        local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        echo "- **Container Environment**: GPU enabled ($gpu_name)"
    else
        echo "- **Container Environment**: No NVIDIA GPU currently attached (CPU mode)"
    fi
}

# Function to get installed tools
get_installed_tools() {
    echo "## Installed Development Tools"
    
    # Languages
    echo -n "- **Languages**: "
    local langs=()
    
    if command -v python3 &>/dev/null; then
        langs+=("Python $(python3 --version 2>&1 | awk '{print $2}')")
    fi
    
    if command -v go &>/dev/null; then
        langs+=("Go $(go version | awk '{print $3}' | sed 's/go//')")
    fi
    
    if command -v node &>/dev/null; then
        langs+=("Node.js $(node --version)")
    fi
    
    echo "${langs[@]}" | sed 's/ /, /g'
    
    # Build Tools
    echo -n "- **Build Tools**: "
    local build_tools=()
    
    if command -v docker &>/dev/null; then
        build_tools+=("Docker $(docker --version | awk '{print $3}' | sed 's/,$//')")
    fi
    
    if command -v dagger &>/dev/null; then
        build_tools+=("Dagger $(dagger version 2>&1 | grep dagger | awk '{print $2}')")
    fi
    
    echo "${build_tools[@]}" | sed 's/ /, /g'
    
    # Infrastructure Tools
    echo -n "- **Infrastructure**: "
    local infra_tools=()
    
    if command -v terraform &>/dev/null; then
        infra_tools+=("Terraform $(terraform version | head -1 | awk '{print $2}')")
    fi
    
    if command -v kubectl &>/dev/null; then
        infra_tools+=("kubectl $(kubectl version --client --short 2>&1 | awk '{print $3}')")
    fi
    
    if command -v helm &>/dev/null; then
        infra_tools+=("Helm $(helm version --short | cut -d: -f2 | tr -d ' ')")
    fi
    
    echo "${infra_tools[@]}" | sed 's/ /, /g'
    
    # Other tools
    if command -v aws &>/dev/null; then
        echo "- **Cloud Tools**: AWS CLI $(aws --version | awk '{print $1}' | cut -d/ -f2)"
    fi
    
    if command -v git &>/dev/null; then
        echo "- **Version Control**: Git $(git --version | awk '{print $3}')"
    fi
    
    if command -v rg &>/dev/null; then
        echo "- **Search**: ripgrep $(rg --version | head -1 | awk '{print $2}') (rg)"
    fi
    
    # Check for VS Code Server
    if pgrep -f "code-server" &>/dev/null; then
        echo "- **IDE**: VS Code Server (web-based) with Python, Claude Code extensions"
    fi
    
    # AI Tools
    local ai_tools=()
    if command -v claude &>/dev/null; then
        ai_tools+=("Claude CLI")
    fi
    if [ -f "$HOME/.aider.conf.yml" ]; then
        ai_tools+=("Aider configured for local LLM")
    fi
    if [ ${#ai_tools[@]} -gt 0 ]; then
        echo "- **AI Tools**: ${ai_tools[@]}" | sed 's/ /, /g'
    fi
}

# Function to get services and integrations
get_services() {
    echo "## Services and Integrations"
    
    # Check environment variables for services
    if [ -n "$MLFLOW_TRACKING_URI" ]; then
        echo "- **MLflow Tracking**: Available at $MLFLOW_TRACKING_URI"
    fi
    
    # Check for LLM service in aider config
    if [ -f "$HOME/.aider.conf.yml" ]; then
        local llm_url=$(grep -E "openai-api-base:|api-base:" "$HOME/.aider.conf.yml" | awk '{print $2}')
        local llm_model=$(grep "model:" "$HOME/.aider.conf.yml" | awk '{print $2}')
        if [ -n "$llm_url" ]; then
            echo "- **Local LLM Service**: $llm_url"
            if [ -n "$llm_model" ]; then
                echo "  - Model: $llm_model"
            fi
        fi
    fi
    
    if [ -n "$CODER_AGENT_URL" ]; then
        echo "- **Coder Agent**: Running at $CODER_AGENT_URL"
    fi
    
    if [ -n "$GH_TOKEN" ]; then
        echo "- **GitHub Token**: Configured in environment"
    fi
    
    if command -v kubectl &>/dev/null; then
        echo "- **Kubernetes Services**: Access to cluster via kubectl"
    fi
}

# Function to get workspace configuration
get_workspace_config() {
    echo "## Workspace Configuration"
    
    # Check for VS Code Server
    local vscode_port=$(ps aux | grep code-server | grep -oP 'port \K\d+' | head -1)
    if [ -n "$vscode_port" ]; then
        echo "- **VS Code Server**: Running on port $vscode_port with web interface"
    fi
    
    echo "- **Terminal**: Bash with VS Code shell integration"
    
    # Python environment
    if [ -n "$VIRTUAL_ENV" ]; then
        echo "- **Python Environment**: Virtual environment at $VIRTUAL_ENV"
    elif [ -d "/opt/venv-py312" ]; then
        echo "- **Python Environment**: System Python $(python3 --version 2>&1 | awk '{print $2}') (venv available at /opt/venv-py312)"
    else
        echo "- **Python Environment**: System Python $(python3 --version 2>&1 | awk '{print $2}') (no venv detected)"
    fi
    
    # Check mount points
    local home_mount=$(mount | grep "/home/$USER" | head -1)
    if [ -n "$home_mount" ]; then
        echo "- **Home Directory**: Persistent storage via $(echo $home_mount | awk '{print $1}')"
    fi
    
    # Configuration files
    echo "- **Config Locations**:"
    [ -f "$HOME/.config/coderv2/config.yaml" ] && echo "  - ~/.config/coderv2/config.yaml"
    [ -f "$HOME/.config/k9s/config.yaml" ] && echo "  - ~/.config/k9s/config.yaml"
    [ -f "$HOME/.aider.conf.yml" ] && echo "  - ~/.aider.conf.yml (configured for local LLM)"
    [ -f "$HOME/.gitconfig" ] && echo "  - ~/.gitconfig (user: $(git config user.name 2>/dev/null || echo 'not set'))"
}

# Main script
cat > "$OUTPUT_FILE" << 'EOF'
# CLAUDE.md - System-Wide Instructions

## Overview
This is a system-wide configuration file for Claude Code that applies to all projects on this system unless overridden by a project-specific CLAUDE.md file.

## System Environment
EOF

get_system_info >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'EOF'

## Development Standards

### Code Style
- Follow existing project conventions and patterns
- Use type hints in Python code
- Prefer functional programming where appropriate
- Write clean, self-documenting code without excessive comments

### Git Workflow
- Write clear, concise commit messages
- Use conventional commit format when applicable
- Always review changes before committing

### File Management
- Always prefer editing existing files over creating new ones
- Only create new files when explicitly required
- Never create documentation files unless specifically requested
- Use appropriate file permissions and ownership

### Security Best Practices
- Never hardcode credentials or secrets
- Use environment variables for configuration
- Follow principle of least privilege
- Validate all user inputs
- Use secure communication protocols

### Testing
- Run tests after making changes
- Use appropriate linting and type checking tools
- Verify builds pass before considering work complete

### Tool Usage
- Use ripgrep (rg) instead of grep for searching
- Prefer native tools over external dependencies
- Check for existing libraries before adding new ones
- Use virtual environments for Python projects

### Communication
- Be concise and direct in responses
- Focus on solving the specific task at hand
- Avoid unnecessary explanations unless requested
- Use file_path:line_number format when referencing code

### Project Context
- Always read and respect project-specific CLAUDE.md files
- Check README files for project conventions
- Look for existing patterns before implementing new solutions
- Maintain consistency with existing codebase

EOF

get_installed_tools >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
get_services >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
get_workspace_config >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'EOF'

## System-Specific Notes
- This is a Coder v2 workspace running in Kubernetes
EOF

# Add current state notes
if ! nvidia-smi &>/dev/null; then
    echo "- Currently running in CPU mode (no GPU attached)" >> "$OUTPUT_FILE"
fi

if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    echo "- Homebrew installed at /home/linuxbrew/.linuxbrew" >> "$OUTPUT_FILE"
fi

if [ -d "/tmp/coder-script-data" ]; then
    echo "- Temporary script data at /tmp/coder-script-data/" >> "$OUTPUT_FILE"
fi

echo "- VS Code web interface accessible via Coder dashboard" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'EOF'

## Path Configuration
- **System PATH includes**:
EOF

# Parse PATH and format nicely
echo "$PATH" | tr ':' '\n' | grep -E "(home|local|brew|venv)" | while read -r path; do
    if [[ "$path" == *"linuxbrew"* ]]; then
        echo "  - $path (Homebrew binaries)" >> "$OUTPUT_FILE"
    elif [[ "$path" == *"venv"* ]]; then
        echo "  - $path (Python venv - $([ -n "$VIRTUAL_ENV" ] && echo "active" || echo "not currently active"))" >> "$OUTPUT_FILE"
    elif [[ "$path" == *".local/bin"* ]]; then
        echo "  - $path" >> "$OUTPUT_FILE"
    fi
done
echo "  - Standard system paths (/usr/local/bin, /usr/bin, etc.)" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'EOF'

## Important Reminders
- Do only what has been asked; nothing more, nothing less
- Always use TodoWrite for complex multi-step tasks
- Mark todos as completed immediately after finishing tasks
- Never assume tools or frameworks are available without checking
- Assist only with defensive security tasks
- Python packages must be installed with python3 -m pip
- Use ripgrep (rg) for code searching, not grep
EOF

# Add final notes based on environment
if [ -z "$VIRTUAL_ENV" ] && [ ! -d "/opt/venv-py312" ]; then
    echo "- This workspace has no active Python virtual environment" >> "$OUTPUT_FILE"
fi

echo ""
echo "System-wide CLAUDE.md generated at: $OUTPUT_FILE"
echo "This file will be used by Claude Code for all projects unless overridden by a project-specific CLAUDE.md"