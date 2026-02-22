# Agent Commit Convention

Agents commit after each meaningful unit of work so progress is visible in
`git log` across sessions.

## Format

```
auto-dev: <scope>: <description>
```

- **scope** — short kebab-case token for the area of change (e.g., `utility-ai`,
  `tests`, `build`, `world-cpp`)
- **description** — imperative mood, lowercase, no trailing period
- Keep the full line under ~72 characters so `git log --oneline` stays readable

## When to Commit

After each logical unit — the smallest set of changes that make sense together.
Multiple small commits are better than one big commit. Commit before switching
concerns.

## Staging

Use explicit file paths only:

```bash
git add src/foo.cpp src/foo.h
```

Never use `git add -A` or `git add .` — these risk staging unrelated files,
especially when multiple agents work in parallel.

## Edge Cases

- **Failing tests:** commit the code change *before* fixing tests. This
  preserves a rollback point.
- **Parallel agents:** only stage and commit files you own. Never commit
  another agent's work.

## Reserved Prefix

`auto-dev: session state` is reserved for the session-stop hook. Agent commits
always include a scope token after `auto-dev:`, so there is no overlap:

```
a1b2c3d auto-dev: utility-ai: add social memory consideration type
d4e5f6g auto-dev: world-cpp: replace apply_component with registry
h7i8j9k auto-dev: session state
```
