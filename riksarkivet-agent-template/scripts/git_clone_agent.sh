#!/usr/bin/env bash
set -euo pipefail

# Script to clone agent repository with GitHub token authentication

AGENT_GIT_REPO="${AGENT_GIT_REPO:-}"
AGENT_GIT_BRANCH="${AGENT_GIT_BRANCH:-main}"
AGENT_WORK_DIR="${AGENT_WORK_DIR:-agent}"
GH_TOKEN="${GH_TOKEN:-}"

# Exit early if no repository specified
if [ -z "$AGENT_GIT_REPO" ]; then
    echo "No agent repository specified, skipping clone."
    exit 0
fi

# Set target directory
TARGET_DIR="/home/coder/${AGENT_WORK_DIR}"

# Check if directory already exists
if [ -d "$TARGET_DIR" ]; then
    echo "Directory $TARGET_DIR already exists."
    
    # Check if it's a git repository
    if [ -d "$TARGET_DIR/.git" ]; then
        echo "Repository already cloned at $TARGET_DIR"
        cd "$TARGET_DIR"
        
        # Fetch latest changes
        echo "Fetching latest changes..."
        if [ -n "$GH_TOKEN" ] && [[ "$AGENT_GIT_REPO" == *"github.com"* ]]; then
            # Use token for private repos
            git remote set-url origin "$(echo "$AGENT_GIT_REPO" | sed "s|https://|https://${GH_TOKEN}@|")"
        fi
        git fetch origin
        
        # Check out the specified branch
        echo "Checking out branch: $AGENT_GIT_BRANCH"
        git checkout "$AGENT_GIT_BRANCH"
        git pull origin "$AGENT_GIT_BRANCH"
        
        # Remove token from URL after operation
        if [ -n "$GH_TOKEN" ] && [[ "$AGENT_GIT_REPO" == *"github.com"* ]]; then
            git remote set-url origin "$AGENT_GIT_REPO"
        fi
        
        echo "Repository updated successfully."
    else
        echo "ERROR: $TARGET_DIR exists but is not a git repository"
        exit 1
    fi
else
    echo "Creating directory $TARGET_DIR..."
    mkdir -p "$(dirname "$TARGET_DIR")"
    
    echo "Cloning $AGENT_GIT_REPO to $TARGET_DIR on branch $AGENT_GIT_BRANCH..."
    
    # Clone with or without token
    if [ -n "$GH_TOKEN" ] && [[ "$AGENT_GIT_REPO" == *"github.com"* ]]; then
        # Use token for GitHub private repos
        CLONE_URL="$(echo "$AGENT_GIT_REPO" | sed "s|https://|https://${GH_TOKEN}@|")"
        GIT_ASKPASS=/bin/true git clone --branch "$AGENT_GIT_BRANCH" "$CLONE_URL" "$TARGET_DIR"
        
        # Remove token from remote URL for security
        cd "$TARGET_DIR"
        git remote set-url origin "$AGENT_GIT_REPO"
        echo "Repository cloned successfully with authentication."
    else
        # Clone without authentication (public repos)
        git clone --branch "$AGENT_GIT_BRANCH" "$AGENT_GIT_REPO" "$TARGET_DIR"
        echo "Repository cloned successfully."
    fi
fi

echo "Git clone completed for $AGENT_WORK_DIR"