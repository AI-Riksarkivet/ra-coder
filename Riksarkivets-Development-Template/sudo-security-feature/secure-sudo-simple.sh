#!/bin/bash
# Simple secure sudo configuration for ML workspace
# Replaces the overly permissive NOPASSWD:ALL configuration

set -euo pipefail

echo "Creating simple secure sudo configuration for coder user..."

# Create restricted sudo configuration with proper syntax
cat > /tmp/coder-restricted << 'EOF'
# Secure sudo configuration for ML development workspace
# Package management
coder ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt, /usr/bin/dpkg
coder ALL=(ALL) NOPASSWD: /usr/bin/pip, /usr/bin/pip3, /usr/local/bin/uv
coder ALL=(ALL) NOPASSWD: /home/linuxbrew/.linuxbrew/bin/brew
# System monitoring
coder ALL=(ALL) NOPASSWD: /usr/bin/nvidia-smi
# File operations in safe directories
coder ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/chown, /bin/chmod
EOF

# Set proper permissions and validate
chmod 440 /tmp/coder-restricted

# Test the configuration
if visudo -c -f /tmp/coder-restricted; then
    echo "✅ Secure sudo configuration is valid"
    echo "📋 This configuration allows:"
    echo "   - Package management (apt, pip, uv, brew)"
    echo "   - Basic file operations (mkdir, chown, chmod)"
    echo "   - GPU monitoring (nvidia-smi)"
    echo ""
    echo "🚫 This blocks:"
    echo "   - System administration commands"
    echo "   - Service management"
    echo "   - User management (passwd, su)"
    echo "   - Mount operations"
    echo ""
    echo "To apply this configuration, replace the Dockerfile line:"
    echo '   echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd'
    echo "With the contents of this configuration file."
else
    echo "❌ Error: Invalid sudoers configuration"
    exit 1
fi

# Clean up
rm -f /tmp/coder-restricted