---
name: orchestrate
description: Bootstrap project state, then execute a given task or pick the next priority
argument-hint: "[optional task description]"
disable-model-invocation: false
user-invocable: true
---

# Orchestrate

You are the project orchestrator. Your job is to understand the current state of the project and either execute the given task or determine the next priority.

## Step 1: Establish Project State

Read `.claude/PROGRESS.md` if it exists. If it doesn't, create it by:
1. Running `git log --oneline -20` to review recent history
2. Exploring the codebase structure with Glob (`**/*`) to understand the project layout
3. Checking for dependencies (package.json, requirements.txt, go.mod, Cargo.toml, etc.)
4. Scanning for tests, CI config, and documentation
5. Writing `.claude/PROGRESS.md` with your findings using this structure:

```markdown
# Project Progress

## Summary
<!-- One paragraph: what this project is and its current phase -->

## In Progress
<!-- Items actively being worked on. Format: - [optional weight] description -->

## Planned
<!-- Items queued for near-term work -->

## Backlog
<!-- Identified but deferred. Priority/weighting is user-defined via CLAUDE.md -->

## Completed
<!-- Last 10-15 completed items for context -->
```

## Step 2: Reconcile State

Compare PROGRESS.md against reality:
- Check `git log` for commits not yet reflected in PROGRESS.md
- Verify in-progress items are still relevant
- Note any drift and correct it

## Step 3: Execute

$ARGUMENTS

**If a task was provided:**
1. Check feasibility — does this conflict with in-progress work? Are dependencies in place?
2. If blockers exist, surface them and propose a path forward
3. Plan the implementation approach
4. Use the Task tool with TeamCreate to spin up agents for design and implementation
5. Update PROGRESS.md as work progresses

**If no task was provided:**
1. Review planned and backlog items in PROGRESS.md
2. Select the highest-priority actionable item (respect any weighting rules from CLAUDE.md)
3. Execute it following the same process above
4. If nothing is actionable, report current state and ask for direction

## Step 4: Update State

After completing work, update `.claude/PROGRESS.md`:
- Move completed items to Completed (keep last 10-15)
- Update in-progress items with current status
- Add any new items discovered during work
- Ensure the document reflects the actual state of the project
