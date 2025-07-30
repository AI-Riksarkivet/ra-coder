#!/bin/bash
# Request additional sudo access for specific tasks
# Usage: ./request-sudo-access.sh <permission-type> [duration]

set -euo pipefail

PERMISSION_TYPE="${1:-}"
DURATION="${2:-1h}"

if [[ -z "$PERMISSION_TYPE" ]]; then
    echo "Usage: $0 <permission-type> [duration]"
    echo ""
    echo "Available permission types:"
    echo "  docker     - Docker daemon access"
    echo "  services   - System service management"
    echo "  network    - Network configuration"
    echo "  system     - System administration"
    echo "  temp-admin - Temporary full admin (requires approval)"
    echo ""
    echo "Duration examples: 30m, 1h, 2h, 1d"
    exit 1
fi

# Function to add temporary sudo rules
add_temp_sudo() {
    local rules="$1"
    local duration="$2"
    local temp_file="/etc/sudoers.d/temp-$(date +%s)"
    
    echo "# Temporary sudo access - expires in $duration" > "$temp_file"
    echo "# Created: $(date)" >> "$temp_file"
    echo "$rules" >> "$temp_file"
    chmod 440 "$temp_file"
    
    # Schedule removal
    echo "sudo rm -f $temp_file" | at now + "$duration" 2>/dev/null || {
        echo "Warning: Could not schedule automatic removal"
        echo "Manual cleanup required: sudo rm -f $temp_file"
    }
    
    echo "✅ Temporary sudo access granted for $duration"
    echo "📄 Rules file: $temp_file"
}

# Check if user has permission to modify sudo config
if ! sudo -v >/dev/null 2>&1; then
    echo "❌ Error: You don't have permission to modify sudo configuration"
    echo "Contact your administrator or use a different workspace configuration"
    exit 1
fi

case "$PERMISSION_TYPE" in
    "docker")
        RULES="coder ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose"
        add_temp_sudo "$RULES" "$DURATION"
        echo "🐳 Docker access granted. You can now use 'sudo docker' commands."
        ;;
    
    "services")
        RULES="coder ALL=(ALL) NOPASSWD: /bin/systemctl, /usr/bin/service, /usr/sbin/nginx, /usr/sbin/apache2"
        add_temp_sudo "$RULES" "$DURATION"
        echo "⚙️  Service management access granted."
        ;;
    
    "network")
        RULES="coder ALL=(ALL) NOPASSWD: /sbin/iptables, /usr/bin/netstat, /sbin/ss, /usr/sbin/tcpdump"
        add_temp_sudo "$RULES" "$DURATION"
        echo "🌐 Network configuration access granted."
        ;;
    
    "system")
        RULES="coder ALL=(ALL) NOPASSWD: /usr/sbin/*, /sbin/*, /bin/mount, /bin/umount"
        add_temp_sudo "$RULES" "$DURATION"
        echo "🔧 System administration access granted."
        ;;
    
    "temp-admin")
        echo "⚠️  WARNING: Requesting temporary full administrative access"
        echo "This grants unrestricted sudo access for $DURATION"
        read -p "Are you sure? (yes/no): " confirm
        
        if [[ "$confirm" = "yes" ]]; then
            RULES="coder ALL=(ALL) NOPASSWD:ALL"
            add_temp_sudo "$RULES" "$DURATION"
            echo "🔴 FULL ADMIN ACCESS GRANTED for $DURATION"
            echo "🚨 Use responsibly - all actions are logged"
        else
            echo "❌ Request cancelled"
            exit 1
        fi
        ;;
    
    *)
        echo "❌ Error: Unknown permission type '$PERMISSION_TYPE'"
        echo "Run '$0' without arguments to see available options"
        exit 1
        ;;
esac

echo ""
echo "📋 Current sudo permissions:"
sudo -l 2>/dev/null | grep -E "may run|NOPASSWD" || echo "No additional permissions found"