#!/bin/bash
# Secure sudo configuration for ML workspace
# Replaces the overly permissive NOPASSWD:ALL configuration

set -euo pipefail

echo "Creating secure sudo configuration for coder user..."

# Remove the existing permissive configuration
rm -f /etc/sudoers.d/nopasswd

# Create restricted sudo configuration
cat > /etc/sudoers.d/coder-restricted << 'EOF'
# Secure sudo configuration for ML development workspace
# Only allows specific commands needed for package management and development

# Package management commands
coder ALL=(ALL) NOPASSWD: /usr/bin/apt-get update, \
                          /usr/bin/apt-get install *, \
                          /usr/bin/apt-get remove *, \
                          /usr/bin/apt-get purge *, \
                          /usr/bin/apt-get autoremove, \
                          /usr/bin/apt-get autoclean, \
                          /usr/bin/apt-get clean, \
                          /usr/bin/dpkg -i *, \
                          /usr/bin/dpkg -r *, \
                          /usr/bin/dpkg --configure *

# Python package managers
coder ALL=(ALL) NOPASSWD: /usr/bin/pip install *, \
                          /usr/bin/pip uninstall *, \
                          /usr/bin/pip3 install *, \
                          /usr/bin/pip3 uninstall *, \
                          /usr/local/bin/uv *

# Homebrew package manager
coder ALL=(ALL) NOPASSWD: /home/linuxbrew/.linuxbrew/bin/brew *

# System services (limited to user services)
coder ALL=(ALL) NOPASSWD: /bin/systemctl --user *

# File operations in specific directories
coder ALL=(ALL) NOPASSWD: /bin/mkdir -p /opt/[A-Za-z0-9_-]*, \
                          /bin/mkdir -p /usr/local/[A-Za-z0-9_-]*, \
                          /bin/chown coder:coder /opt/[A-Za-z0-9_-]*, \
                          /bin/chown coder:coder /usr/local/[A-Za-z0-9_-]*

# GPU and hardware access (for ML workloads)
coder ALL=(ALL) NOPASSWD: /usr/bin/nvidia-smi, \
                          /usr/bin/nvidia-ml-py*

# Development tools
coder ALL=(ALL) NOPASSWD: /usr/local/bin/code-server, \
                          /usr/bin/git

EOF

# Set proper permissions for sudoers file
chmod 440 /etc/sudoers.d/coder-restricted

# Validate the sudoers configuration
if visudo -c -f /etc/sudoers.d/coder-restricted; then
    echo "✅ Secure sudo configuration created successfully"
    echo "📋 Allowed commands:"
    echo "   - Package management (apt, pip, uv, brew)"
    echo "   - File operations in /opt and /usr/local"
    echo "   - User systemctl services"
    echo "   - Development tools (git, code-server)"
    echo "   - GPU monitoring (nvidia-smi)"
    echo ""
    echo "🚫 Blocked commands:"
    echo "   - System administration (su, mount, passwd)"
    echo "   - Service management (system services)"
    echo "   - Dangerous permissions (chmod 777, setuid)"
else
    echo "❌ Error: Invalid sudoers configuration"
    exit 1
fi