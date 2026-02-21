---
name: orchestrate
description: >-
  Bootstrap project state, then execute a given task or pick the next priority.
  Use this whenever someone wants to continue development, asks what to work on,
  says "pick up where we left off", wants autonomous task execution, or needs
  help with project priorities and task orchestration — even if they don't
  explicitly say "orchestrate."
argument-hint: "[optional task description]"
disable-model-invocation: false
user-invocable: true
---

# Orchestrate

You are the continuity layer between development sessions. Your job is to
quickly understand where a project stands, decide what to do, do it well, and
leave accurate state behind for the next session. Every session that starts
after yours will read the state you leave — treat it like a handoff note to
a teammate who's about to sit down at your desk.

The auto-dev plugin supports you: the SessionStart hook injects PROGRESS.md
into your context automatically, and the Stop hook auto-commits uncommitted
changes. Your role is everything in between.

## Phase 1: Establish Context

Look for project state in this order:

1. Check whether the SessionStart hook already injected PROGRESS.md into your
   context — if so, you already have it.
2. Read `.claude/PROGRESS.md` (the canonical location the hook expects).
3. If not there, check for `PROGRESS.md` at the project root (some projects
   store it there). If you find it at the root, use it — but when you next
   update it, move it to `.claude/PROGRESS.md` so the SessionStart hook can
   find it in future sessions.

**If PROGRESS.md exists:** you have project state. Move to Phase 2.

**If PROGRESS.md doesn't exist anywhere:** this is a first-time orchestration.
Bootstrap it:

1. **Recent history** — `git log --oneline -20` to understand what's been
   happening. Commit messages reveal what the project cares about.
2. **Project shape** — look for entry points and configuration, not every file.
   Check the root for config files (package.json, Cargo.toml, pyproject.toml,
   go.mod, etc.), scan for src/lib/app directories, find test directories
   and CI config. Understand the *architecture*, not the file tree.
3. **Current state** — `git status` and `git diff --stat`. Is there work in
   flight? Uncommitted changes? Unmerged branches?
4. **Project documentation** — check for README, CLAUDE.md, CONTRIBUTING.md.
   These tell you how the project wants to be worked on.

Then write `.claude/PROGRESS.md` following the template in
`references/progress-template.md`. Be honest about what you found — if the
project is early-stage with nothing in progress, say that. Don't invent items
to fill sections.

## Phase 2: Reconcile State

PROGRESS.md might be stale. Sessions crash, users work outside Claude, other
contributors push changes. Before acting on state, verify it.

1. **Check git log since last known activity.** Compare recent commits against
   what PROGRESS.md says is in progress and completed. If commits finished a
   listed in-progress item, move it. If there's new work not reflected in
   PROGRESS.md, add it.

2. **Verify in-progress items are real.** If something has been "in progress"
   across multiple sessions with no corresponding commits, it's probably
   stalled or abandoned. Flag it — don't silently carry it forward.

3. **Check for branch divergence.** Unmerged branches with significant work?
   Open PRs? This is context that affects what you should do next.

4. **Update PROGRESS.md** with corrections. Keep them minimal and accurate —
   this is bookkeeping, not a rewrite.

## Phase 3: Execute

$ARGUMENTS

### If a task was given

Assess before acting:

- **Scope** — is this a focused change (one file, one function) or does it
  touch multiple systems? This determines whether you work directly or plan.
- **Conflicts** — does this interfere with anything in progress? If so, surface
  the conflict and propose how to handle it.
- **Dependencies** — does this need something that doesn't exist yet? Handle
  the dependency first, or tell the user.

**For focused tasks** (clear scope, single concern): just do the work. Read
the relevant code, make the change, verify it works. Don't over-plan and
don't spin up teams for something you can do directly.

**For larger tasks** (multiple files, multiple concerns, design decisions):
plan the approach first. Break the work into concrete steps. If the task has
genuinely independent workstreams (say, separate frontend and backend work),
use the Task tool to spin up agents for parallel execution. But a task that
touches 5 files sequentially doesn't need a team — the coordination overhead
isn't worth it for anything you could do in a few minutes directly. When you
do use teams, give each agent a specific, well-scoped assignment with clear
success criteria.

### If no task was given

You're being asked "what's next?" — this is a judgment call.

1. Review PROGRESS.md priorities. If the user has defined weights or ordering
   rules in CLAUDE.md, respect them.
2. Prefer items that are:
   - Unblocked (no dependencies on incomplete work)
   - Well-defined (you can start without extensive clarification)
   - High-impact relative to effort
3. If multiple items seem equally viable, pick one and explain why. Don't
   present a menu unless the decision genuinely requires user input — product
   direction choices need their input, technical sequencing choices don't.
4. If nothing is actionable — everything blocked, unclear, or the backlog is
   empty — say so plainly and ask for direction.

## Phase 4: Update State

After completing work (or making meaningful progress on longer tasks), update
`.claude/PROGRESS.md`. This matters because the next session reads this file
to understand where things stand. Inaccurate state wastes future time.

- Move completed items to Completed (keep the last 10–15 for context)
- Update in-progress items with honest status — "started" vs "mostly done,
  needs tests" vs "blocked on X" are useful distinctions
- Add newly discovered items to Planned or Backlog as appropriate
- If you changed direction or discovered something unexpected, note it

Follow the template structure in `references/progress-template.md`. Don't
restructure the file or add new sections — consistency across sessions matters
more than creativity here.
