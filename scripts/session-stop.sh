#!/usr/bin/env bash
set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD="${CWD:-$PWD}"

cd "$CWD"

# Skip if not in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    exit 0
fi

# Only stage plugin state — not the user's code.
# The plugin owns .claude/ (including PROGRESS.md) and a root-level
# PROGRESS.md if it hasn't been moved yet. Everything else belongs
# to the user and should be committed intentionally.
STAGED=false

if [ -d ".claude" ]; then
    git add .claude/ 2>/dev/null && STAGED=true
fi

# Catch PROGRESS.md at project root (pre-migration location)
if [ -f "PROGRESS.md" ]; then
    git add PROGRESS.md 2>/dev/null && STAGED=true
fi

# Skip if nothing was staged or staged files are unchanged
if ! $STAGED || git diff --cached --quiet 2>/dev/null; then
    exit 0
fi

git commit -m "auto-dev: session state" 2>/dev/null || true

exit 0
