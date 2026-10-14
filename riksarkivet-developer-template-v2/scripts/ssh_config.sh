#!/usr/bin/env bash

set -euo pipefail

echo "Setting up SSH keys for Git authentication..."
mkdir -p /home/coder/.ssh
chmod 700 /home/coder/.ssh

# SSH private key from Terraform parameter
SSH_PRIVATE_KEY="${ssh_private_key}"

# Check if SSH private key parameter is provided
if [ ! -z "$SSH_PRIVATE_KEY" ] && [ "$SSH_PRIVATE_KEY" != "" ]; then
  echo "Using provided SSH private key..."
  echo "$SSH_PRIVATE_KEY" > /home/coder/.ssh/id_rsa
  chmod 600 /home/coder/.ssh/id_rsa
  
  # Generate public key from private key
  ssh-keygen -y -f /home/coder/.ssh/id_rsa > /home/coder/.ssh/id_rsa.pub 2>/dev/null || echo "Warning: Could not generate public key"
  chmod 644 /home/coder/.ssh/id_rsa.pub
  
  echo "SSH private key configured from parameter."
elif [ ! -f /home/coder/.ssh/id_rsa ]; then
  echo "Generating new SSH key pair..."
  ssh-keygen -t rsa -b 4096 -f /home/coder/.ssh/id_rsa -N "" -C "${git_author_email}" >/dev/null 2>&1
  chmod 600 /home/coder/.ssh/id_rsa
  chmod 644 /home/coder/.ssh/id_rsa.pub
  echo "SSH key generated successfully."
  echo ""
  echo "-----------------------------------------------------"
  echo "SSH PUBLIC KEY FOR GIT AUTHENTICATION:"
  echo "-----------------------------------------------------"
  cat /home/coder/.ssh/id_rsa.pub
  echo "-----------------------------------------------------"
  echo "Add this key to your Git provider (Azure DevOps, GitHub, etc.)"
  echo "-----------------------------------------------------"
  echo ""
else
  echo "SSH key already exists at /home/coder/.ssh/id_rsa"
fi

# Configure SSH for common Git hosts
cat > /home/coder/.ssh/config <<'SSHCONFIG'
Host devops.ra.se
    HostName devops.ra.se
    Port 22
    User git
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host ssh.dev.azure.com
    HostName ssh.dev.azure.com
    User git
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host github.com
    HostName github.com
    User git
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
SSHCONFIG
chmod 600 /home/coder/.ssh/config

# Set proper ownership
chown -R coder:coder /home/coder/.ssh
