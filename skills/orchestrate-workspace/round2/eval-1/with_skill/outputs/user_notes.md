# User Notes

## Uncertainty
- The social system's tick=0 in memory entries may be intentional (storing social interactions without temporal context) or a bug (missed when the spatial memory feature was added). The PROGRESS.md entry for the social memory task implicitly assumes it's a fixable limitation ("recency-weighted like spatial memory"), but if the social system was deliberately simplified, the clock plumbing may be an unexpected additional scope item.
- The priority scoring system in PROGRESS.md uses `[I:x U:y E:z = score]` notation. Only one item remains in Next Up with a score. Without competing items to compare against, the "pick the highest priority" logic is trivially satisfied — but this means the recommendation is less of a judgment call and more of a direct lookup.

## Needs Human Review
- The social_memory consideration design (scoring based on best recent positive interaction) is a reasonable starting point but may produce odd behavior: if an agent had one great interaction 5000 ticks ago and many recent mediocre ones, the old great one might outscore the recent ones due to high sentiment * moderate recency vs low sentiment * high recency. The weighting strategy may need tuning after observing agent behavior.
- The recommendation to commit uncommitted test files before starting new work is standard practice, but the user may have deliberately left them uncommitted (e.g., tests not yet passing, still iterating). Since this is read-only eval, I couldn't verify by running the test suite.

## Workarounds
- The input files directory did not exist and was created during execution. This is expected for this eval since no input files were needed.
- Since this is a READ-ONLY eval, no actual code changes, file moves, or git operations were performed. The transcript documents what WOULD be done.

## Suggestions
- The skill's Phase 2 reconciliation step would benefit from explicitly noting uncommitted work as a "pre-flight check" — the current instructions say to verify in-progress items and check git log, but don't specifically call out "if there's uncommitted work from a previous session, address it first."
- The social system should probably be refactored to receive the simulation clock (or at least a tick counter) during registration, similar to how the AI system implicitly has tick context. This is needed for any time-sensitive social features.
