#!/usr/bin/env zsh

# TODO: Set up for IDUN with https://github.com/musistudio/claude-code-router

# Configuration for Kimi (Moonshot AI)
# Change this variable if you want to use a different model in the future
KIMI_MODEL="kimi-k2-thinking-turbo"

# Function to run Claude Code with Kimi K2 Thinking Turbo (Moonshot AI)
# This uses the Moonshot API which is compatible with the Anthropic SDK.
#
# Usage:
#   kimi [args]  - Runs claude with Kimi K2 model
#   k2 [args]    - Alias for kimi
#
# Note: These environment variables are set only for the duration of the 
# claude command, so they don't pollute your shell environment.
kimi_code() {
    # Check if MOONSHOT_API_KEY is available (should be in ~/.secrets)
    if [[ -z "$MOONSHOT_API_KEY" ]]; then
        echo "Error: MOONSHOT_API_KEY is not set."
        echo "Please ensure it is exported in your ~/.secrets file."
        return 1
    fi

    # Check if claude is installed
    if ! command -v claude &> /dev/null; then
        echo "Error: 'claude' command not found."
        echo "Please install it with: npm install -g @anthropic-ai/claude-code"
        return 1
    fi

    # Run claude with Moonshot-specific environment variables
    ANTHROPIC_BASE_URL=https://api.moonshot.ai/anthropic \
    ANTHROPIC_AUTH_TOKEN="$MOONSHOT_API_KEY" \
    ANTHROPIC_MODEL="$KIMI_MODEL" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="$KIMI_MODEL" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$KIMI_MODEL" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$KIMI_MODEL" \
    CLAUDE_CODE_SUBAGENT_MODEL="$KIMI_MODEL" \
    claude "$@"
}
