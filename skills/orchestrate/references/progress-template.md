# PROGRESS.md Template

Use this template when creating `.claude/PROGRESS.md` for the first time.
Adapt section depth to the project — a small script doesn't need the same
detail as a monorepo.

---

```markdown
# Project Progress

## Summary
<!-- One paragraph. What this project is, what phase it's in, and what the
current focus area is. Update this each session — it's the first thing the
next session reads. Write it like a handoff note: "This is a CLI tool for X.
We're currently focused on adding Y. The main blocker is Z." -->

## Architecture
<!-- Brief project layout and key tech decisions. Helps agents ground their
work without exploring the codebase. Skip for trivial projects.

Example:
src/           Express API routes and middleware
lib/           Shared utilities, database client
tests/         Jest tests — 42 cases, 6 suites

Stack: TypeScript, Express, PostgreSQL, Redis for caching.
-->

## In Progress
<!-- Items actively being worked on. Each entry needs enough context that a
new session can pick it up without re-investigating.

Format: - [description] — [current status / what remains]

Example:
- Add user authentication — JWT middleware done, need login/signup routes and tests
- Fix flaky CI on main — identified race condition in test setup, drafting fix
-->

## Planned
<!-- Items queued for near-term work, roughly in priority order. Well-defined
enough to start without extensive clarification.

Format: - [description]

Example:
- Add rate limiting to API endpoints
- Migrate database from SQLite to PostgreSQL
-->

## Backlog
<!-- Identified but not yet prioritized or fully scoped. May need design work
before they're ready. This isn't a product roadmap — only include items
concretely identified during development.

Format: - [description]

Example:
- Consider caching layer for expensive queries
- Internationalization support
-->

## Known Issues
<!-- Problems identified but not yet fixed. Include enough detail that a
future session can act on them without re-diagnosing.

Format: - [what's wrong] — [where, impact, potential fix direction]

Example:
- Response times spike above 500 concurrent users — connection pool maxes out, need pooling config or read replicas
- Circular dependency between auth and user modules — causes test isolation issues
-->

## Completed
<!-- Last 10-15 completed items for context. Prune older entries as new ones
are added.

Format: - [description]

Example:
- Set up project scaffold with Express + TypeScript
- Add health check endpoint and basic error handling
-->
```

---

## Guidelines

- **Be concrete, not aspirational.** "Add authentication" is vague. "Add JWT
  auth with login/signup endpoints" tells the next session what to actually do.
- **Keep entries honest.** If something is stalled, say so. If you're unsure
  about scope, say that. Dishonest state wastes future sessions' time.
- **In Progress should be small.** More than 3-4 items usually means something
  is stalled. Move stalled items back to Planned with a note about why.
- **The Summary is the most important section.** A new session reads it first
  and uses it to orient. Keep it current.
