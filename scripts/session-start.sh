#!/usr/bin/env bash
set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD="${CWD:-$PWD}"

# --- Locate PROGRESS.md ---
PROGRESS=""
PROGRESS_NOTE=""

if [ -f "$CWD/.claude/PROGRESS.md" ]; then
    PROGRESS=$(cat "$CWD/.claude/PROGRESS.md")
elif [ -f "$CWD/PROGRESS.md" ]; then
    PROGRESS=$(cat "$CWD/PROGRESS.md")
    PROGRESS_NOTE="(located at project root — move to .claude/PROGRESS.md for auto-injection)"
fi

# --- Capture git state ---
GIT_STATE=""
if git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "detached")
    LOG=$(git -C "$CWD" log --oneline -15 2>/dev/null || echo "no commits")
    STATUS=$(git -C "$CWD" status --short 2>/dev/null || true)
    DIFF_STAT=$(git -C "$CWD" diff --stat 2>/dev/null || true)

    GIT_STATE="## Git State
Branch: ${BRANCH}

### Recent commits
${LOG}

### Working tree
${STATUS:-clean}"

    if [ -n "$DIFF_STAT" ]; then
        GIT_STATE="${GIT_STATE}

### Unstaged changes
${DIFF_STAT}"
    fi
fi

# --- Build context ---
CTX=""
if [ -n "$PROGRESS" ]; then
    CTX="## PROGRESS.md ${PROGRESS_NOTE}

${PROGRESS}"
else
    CTX="No PROGRESS.md found. First-time orchestration — establish project state."
fi

if [ -n "$GIT_STATE" ]; then
    CTX="${CTX}

${GIT_STATE}"
fi

jq -n --arg ctx "$CTX" '{"additionalContext": $ctx}'
