#!/bin/bash
set -e

# Agent Runner Script
# Executes Claude Code with the task prompt and stops the workspace when done

echo "=== Agent Runner ==="

# Check if auto-run is enabled
if [ "$AGENT_AUTO_RUN" != "true" ]; then
    echo "Auto-run is disabled. To run the agent manually, use:"
    echo "  claude-code '$CODER_MCP_CLAUDE_TASK_PROMPT'"
    echo "To auto-stop workspace after manual run:"
    echo "  coder stop $CODER_WORKSPACE_NAME -y"
    exit 0
fi

# Check if task prompt is provided
if [ -z "$CODER_MCP_CLAUDE_TASK_PROMPT" ]; then
    echo "No task prompt provided. Skipping agent execution."
    echo "To run an agent task, set the 'Agent Task Instructions' parameter when creating the workspace."
    exit 0
fi

# Check if API key is available
if [ -z "$CODER_MCP_CLAUDE_API_KEY" ]; then
    echo "Warning: No Anthropic API key found."
    echo "Please enable 'Advanced Tools' and provide an API key to use Claude Code."
    exit 1
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

# Execute Claude Code with the task prompt
claude-code "$CODER_MCP_CLAUDE_TASK_PROMPT"
AGENT_EXIT_CODE=$?

echo "---"
echo "Agent exit code: $AGENT_EXIT_CODE"
echo "Completed at: $(date)"

# Stop the workspace after completion
echo "=== Stopping workspace in 10 seconds... ==="
echo "To cancel shutdown, press Ctrl+C now"
sleep 10

echo "Stopping workspace: $CODER_WORKSPACE_NAME"
coder stop "$CODER_WORKSPACE_NAME" -y

echo "=== Agent task complete, workspace stopping ==="