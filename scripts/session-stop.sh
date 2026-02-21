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

# Skip if no changes exist
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    exit 0
fi

# Stage all changes
git add -A

# Build commit message from what changed
CHANGED_FILES=$(git diff --cached --name-only)
FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l | tr -d ' ')
FILE_LIST=$(echo "$CHANGED_FILES" | head -5 | tr '\n' ', ' | sed 's/,$//')

if [ "$FILE_COUNT" -gt 5 ]; then
    MSG="auto-dev: update ${FILE_COUNT} files (${FILE_LIST}, ...)"
else
    MSG="auto-dev: update ${FILE_LIST}"
fi

git commit -m "$MSG" 2>/dev/null || true

exit 0
