#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Git user..."
echo "Git author name: '${git_author_name}'"
echo "Git author email: '${git_author_email}'"

if git config --global user.name "${git_author_name}"; then
    echo "Successfully set git user.name to '${git_author_name}'"
else
    echo "ERROR: Failed to set git user.name"
    exit 1
fi

if git config --global user.email "${git_author_email}"; then
    echo "Successfully set git user.email to '${git_author_email}'"
else
    echo "ERROR: Failed to set git user.email"
    exit 1
fi

# Verify git configuration
echo "Current git configuration:"
git config --list | grep user || echo "WARNING: No git user config found"

echo "Git configuration completed."
