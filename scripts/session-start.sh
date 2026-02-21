#!/usr/bin/env bash
set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD="${CWD:-$PWD}"

PROGRESS_FILE="$CWD/.claude/PROGRESS.md"

if [ -f "$PROGRESS_FILE" ]; then
    jq -n --arg ctx "$(cat "$PROGRESS_FILE")" \
        '{"additionalContext": ("Current project state from PROGRESS.md:\n\n" + $ctx)}'
else
    echo '{"additionalContext": "No .claude/PROGRESS.md found. If starting meaningful work, establish project state by creating .claude/PROGRESS.md."}'
fi
