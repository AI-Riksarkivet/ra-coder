#!/bin/bash
# Remove 'set -e' to prevent script from exiting on any command failure
# set -e

# Agent Runner Script
# Executes Claude Code with the task prompt and stops the workspace when done

echo "=== Agent Runner ==="

# Check if auto-run is enabled
if [ "$AGENT_AUTO_RUN" != "true" ]; then
    echo "Auto-run is disabled. To run the agent manually, use:"
    echo "  claude '$CODER_MCP_CLAUDE_TASK_PROMPT'"
    echo "To auto-stop workspace after manual run:"
    echo "  coder stop $CODER_WORKSPACE_NAME -y"
    exit 0
fi

# Check if task prompt is provided
if [ -z "$CODER_MCP_CLAUDE_TASK_PROMPT" ]; then
    echo "No task prompt provided. Skipping agent execution."
    echo "To run an agent task, set the 'Agent Task Instructions' parameter when creating the workspace."
fi

# Determine authentication mode
AUTH_MODE="browser"
if [ -n "$CODER_MCP_CLAUDE_API_KEY" ]; then
    echo "API key detected - will use API authentication"
    AUTH_MODE="api"
else
    echo "No API key provided - will use browser authentication (automatic login)"
    AUTH_MODE="browser"
fi

# Wait for git clone to complete if repository is specified
if [ -n "$AGENT_GIT_REPO" ]; then
    echo "Waiting for repository clone to complete..."
    WAIT_COUNT=0
    while [ ! -d "/home/coder/$AGENT_WORK_DIR" ] && [ $WAIT_COUNT -lt 30 ]; do
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done
    
    if [ -d "/home/coder/$AGENT_WORK_DIR" ]; then
        echo "Repository found at: /home/coder/$AGENT_WORK_DIR"
        cd "/home/coder/$AGENT_WORK_DIR"
    else
        echo "Warning: Repository directory not found after waiting"
    fi
fi

echo "=== Executing Agent Task ==="
echo "Workspace: $CODER_WORKSPACE_NAME"
echo "Task: $CODER_MCP_CLAUDE_TASK_PROMPT"
echo "Starting at: $(date)"
echo "---"

# Only execute if we have a task prompt
if [ -n "$CODER_MCP_CLAUDE_TASK_PROMPT" ]; then
    # Wait for claude CLI to be installed (max 120 seconds)
    echo "Waiting for claude CLI to be installed..."
    WAIT_COUNT=0
    while ! command -v claude &> /dev/null && [ $WAIT_COUNT -lt 60 ]; do
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $((WAIT_COUNT % 5)) -eq 0 ]; then
            echo "Still waiting for claude CLI... ($WAIT_COUNT/60)"
        fi
    done

    if command -v claude &> /dev/null; then
        echo "claude CLI found at: $(which claude)"

        # Execute Claude with the appropriate authentication method
        if [ "$AUTH_MODE" = "browser" ]; then
            echo "Using browser authentication (automatic login)..."
            echo "Note: Browser authentication will open a browser window for login if needed"
            # For browser auth, claude will automatically handle the login flow
            claude "$CODER_MCP_CLAUDE_TASK_PROMPT"
            AGENT_EXIT_CODE=$?
        else
            echo "Using API key authentication..."
            # API key is already set in environment
            claude "$CODER_MCP_CLAUDE_TASK_PROMPT"
            AGENT_EXIT_CODE=$?
        fi
    else
        echo "Error: claude CLI not found after 120 seconds"
        echo "Please check the Claude module installation logs"
        AGENT_EXIT_CODE=127
    fi

    echo "---"
    echo "Agent exit code: $AGENT_EXIT_CODE"
    echo "Completed at: $(date)"

    # Stop the workspace after completion
    echo "=== Stopping workspace in 10 seconds... ==="
    echo "To cancel shutdown, press Ctrl+C now"
    sleep 10

    ##echo "Stopping workspace: $CODER_WORKSPACE_NAME"
    ##coder stop "$CODER_WORKSPACE_NAME" -y

    echo "=== Agent task complete, workspace stopping ==="
else
    echo "=== Agent execution skipped - no task prompt provided ==="
fi