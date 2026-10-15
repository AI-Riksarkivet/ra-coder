#!/usr/bin/env bash

set -euo pipefail

echo "Setting up Nix (single-user, with flakes)..."

# Temporary hint for users who open a terminal while tools are installing.
# Removed at the end of this script.
touch "$HOME/.bashrc"
grep -qF "Dev tools are still installing" "$HOME/.bashrc" || cat >> "$HOME/.bashrc" <<'HINT'
[ -e "$HOME/.nix-profile/bin/starship" ] || echo "🔧 Dev tools are still installing in the background - watch progress: tail -f /tmp/nix_setup.log"
HINT

# Preflight checks
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found in image"; exit 1; }
command -v xz   >/dev/null 2>&1 || { echo "ERROR: xz not found in image (required to unpack Nix)"; exit 1; }

# Install Nix if not already present (the /nix store is persistent via PVC,
# so this normally runs only on the first workspace start)
if ! command -v nix >/dev/null 2>&1; then
  echo "Installing Nix..."
  # --no-channel-add: we use flakes, skip the slow nixpkgs channel download
  curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon --no-channel-add
fi

# Make nix available in this script
. "$HOME/.nix-profile/etc/profile.d/nix.sh"

# Enable flakes and the nix command; sandboxing is unavailable in the
# workspace container, so disable it explicitly to silence warnings
mkdir -p "$HOME/.config/nix"
touch "$HOME/.config/nix/nix.conf"
grep -q "^experimental-features" "$HOME/.config/nix/nix.conf" || \
  echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
grep -q "^sandbox" "$HOME/.config/nix/nix.conf" || \
  echo "sandbox = false" >> "$HOME/.config/nix/nix.conf"

# Install the workspace toolset from the template flake
mkdir -p "$HOME/devshell"
echo "${flake_nix_b64}" | base64 -d > "$HOME/devshell/flake.nix"

# Replace any previously installed toolset with the selected profile
# (keeps profile switching clean and avoids binary conflicts)
for entry in $(nix profile list 2>/dev/null | awk '/^Name:/ {print $2}' | grep -vx nix); do
  nix profile remove "$entry" || true
done

echo "Installing '${nix_profile}' toolset via nix profile (first run downloads all packages and may take a while)..."
nix profile add "$HOME/devshell#${nix_profile}"

# Remove the "still installing" terminal hint
sed -i '/Dev tools are still installing/d' "$HOME/.bashrc"

echo "Nix setup complete. Tools are on PATH for new shells via ~/.nix-profile."
