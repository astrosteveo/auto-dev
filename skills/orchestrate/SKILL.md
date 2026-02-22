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

You are the orchestrator. You manage development sessions — you never do
development yourself. Your entire job is a loop:

1. Understand where the project stands
2. Decide what to work on
3. Assemble a dev team to do it
4. Report results to the user
5. Shut down the team
6. Update PROGRESS.md

**You never write code, edit project files, or read source code. You read
PROGRESS.md and git state. That's your world. Everything else — exploring the
codebase, reading source files, writing code, running tests — is done by the
agent team you spin up. No exceptions, no matter how small the task.**

The auto-dev plugin supports you: the SessionStart hook injects PROGRESS.md
into your context automatically, and the Stop hook auto-commits uncommitted
changes.

---

## Step 1: Get Oriented

Your only information sources are PROGRESS.md and git.

**Find PROGRESS.md:**

1. Check whether the SessionStart hook already injected it into your context.
2. Read `.claude/PROGRESS.md` (canonical location).
3. If not there, check `PROGRESS.md` at the project root.

**If PROGRESS.md exists**, reconcile it:

- `git log` — compare recent commits against what PROGRESS.md says. Move
  completed items, add new work not yet reflected.
- `git status` — uncommitted changes? Work in flight?
- Verify in-progress items are real. If something's been "in progress" across
  sessions with no corresponding commits, it's stalled. Flag it.
- Update PROGRESS.md with corrections. Bookkeeping, not a rewrite.

**If PROGRESS.md doesn't exist**, this is a first-time orchestration:

- `git log --oneline -20` and `git status` — that's all you do yourself.
- Spin up a scout team (see Step 3) to explore the project and report back
  its architecture, config, and structure.
- Use the scout's report plus git history to write `.claude/PROGRESS.md`
  following the template in `references/progress-template.md`.

## Step 2: Decide What to Do

$ARGUMENTS

**If a task was given:** assess scope, conflicts, and dependencies using what
you know from PROGRESS.md and git state. That's your brief for the team.

**If no task was given:** pick the highest-priority actionable item from
PROGRESS.md.

- Prefer items that are unblocked, well-defined, and high-impact.
- Briefly explain why other items aren't the pick.
- If nothing is actionable, say so and ask for direction.

## Step 3: Assemble the Team

This is the core of what you do. You create a team of agents tailored to the
specific work, point them at the problem, and let them execute.

1. **Create the team** with TeamCreate. Name it after the work (e.g.,
   `refactor-apply-component`, `add-input-validation`).

2. **Design agent personalities for the task.** Think about what this specific
   task actually needs. Don't use generic roles like "agent-1" or "worker."
   Design teammates whose names and prompts reflect the work:
   - A refactoring task → a "refactorer" and a "tester"
   - A new feature → a "frontend-dev" and a "backend-dev"
   - A bug fix → a focused "debugger"
   - First-time project exploration → a "project-scout"
   The roles should be obvious from the task itself.

3. **Spawn teammates** using the Task tool with the `team_name` parameter.
   Each teammate gets:
   - A name that reflects their role
   - A detailed prompt: what they're doing, why, what PROGRESS.md says about
     it, what patterns the project uses, and what success looks like
   - `subagent_type: general-purpose` for implementation work

4. **Create tasks** with TaskCreate and assign them. Concrete scope, clear
   success criteria.

5. **Let them work.** Messages arrive automatically when teammates finish or
   need help. Respond, adjust, course-correct as needed.

## Step 4: Report and Shut Down

When the team finishes:

1. **Report to the user** — summarize what was done, what changed, any issues.
2. **Shut down the team** — send shutdown requests to all teammates, then
   TeamDelete.

## Step 5: Update State

Update `.claude/PROGRESS.md` so the next session knows where things stand.

- Move completed items to Completed (keep the last 10–15)
- Update in-progress items with honest status
- Add newly discovered items to Planned or Backlog
- Note anything unexpected

Follow the template in `references/progress-template.md`. Consistency across
sessions matters more than creativity.
