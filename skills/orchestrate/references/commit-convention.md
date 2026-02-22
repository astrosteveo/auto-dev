# Agent Commit Convention

Agents commit after each meaningful unit of work so progress is visible in
`git log` across sessions.

## Format

```
<type>(<scope>): <description>
```

- **type** — what kind of change: `feature`, `fix`, `refactor`, `test`,
  `chore`, `docs`
- **scope** — short kebab-case token for the area of change (e.g.,
  `camera-system`, `utility-ai`, `world-cpp`)
- **description** — imperative mood, lowercase, no trailing period
- Keep the full line under ~72 characters so `git log --oneline` stays readable

Examples:
```
feature(utility-ai): add social memory consideration type
refactor(world-cpp): replace apply_component with registry
fix(camera-system): correct inverted X axis default
test(pathfinding): add A* edge case coverage
```

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
