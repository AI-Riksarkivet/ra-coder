#!/usr/bin/env bash
set -euo pipefail

echo "Setting up Starship prompt..."

# Install JetBrains Mono Nerd Font
echo "Installing JetBrains Mono Nerd Font (this may take a moment)..."
mkdir -p ~/.local/share/fonts

# Download quietly (no progress bar)
if wget -q -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip; then
    cd ~/.local/share/fonts
    
    # Extract quietly
    unzip -q -o JetBrainsMono.zip
    rm -f JetBrainsMono.zip
    
    # Update font cache if fc-cache is available
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f ~/.local/share/fonts >/dev/null 2>&1
        echo "Font cache updated."
    else
        echo "Note: fc-cache not available, skipping font cache update."
    fi
    
    echo "JetBrains Mono Nerd Font installed successfully."
else
    echo "Warning: Failed to download Nerd Font. Continuing without it..."
fi

# Add Starship initialization to .bashrc
if ! grep -q "starship init bash" /home/coder/.bashrc; then
    echo 'eval "$(starship init bash)"' >> /home/coder/.bashrc
    echo "Added Starship initialization to .bashrc"
fi

# Apply Catppuccin powerline preset
mkdir -p /home/coder/.config
if command -v starship >/dev/null 2>&1; then
    starship preset catppuccin-powerline -o /home/coder/.config/starship.toml
    echo "Applied Catppuccin powerline preset."
    
    # Test that starship works
    echo "Testing Starship installation..."
    eval "$(starship init bash)"
    if starship --version >/dev/null 2>&1; then
        echo "✓ Starship is ready! ($(starship --version))"
    fi
else
    echo "Warning: Starship command not found!"
fi

# Set ownership
chown -R coder:coder /home/coder/.config 2>/dev/null || true
chown -R coder:coder /home/coder/.local/share/fonts 2>/dev/null || true
chown coder:coder /home/coder/.bashrc 2>/dev/null || true

echo "Starship prompt configuration completed."
