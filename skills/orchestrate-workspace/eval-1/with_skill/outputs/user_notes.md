# User Notes

## Uncertainty
- The PROGRESS.md priority scoring format `[I:3 U:4 E:3 = 2.33]` appears to be Impact * Utility / Effort, but this is inferred from the numbers — no documentation explains the scoring formula. I treated the composite score as the priority ranking, which seems correct given the ordering.
- The uncommitted test files in the working tree appear to be completed work, but I did not verify they compile or pass since this is a read-only eval. In a real execution, I would run the test suite before committing.

## Needs Human Review
- The decision to recommend Social memory AI decisions as the next task is straightforward (it's the only Next Up item), but the user may have opinions about whether to address the known issue (apply_component refactor) first, since adding social memory considerations will add another branch to that hardcoded if/else chain.
- Whether to commit the uncommitted test work before starting — this is almost certainly the right call, but the user might have left it uncommitted intentionally.

## Workarounds
- The skill specifies `.claude/PROGRESS.md` as the progress file location, but this project stores it at the repository root (`/PROGRESS.md`). I adapted by reading from the actual location. The skill should either support configurable paths or the project should match the expected convention.
- The PROGRESS.md in this project does not have a separate "In Progress" section (per the template). It has "Completed", "Known Issues", "Next Up", and "Deferred". The skill's Phase 2 reconciliation step about verifying "in-progress items" was adapted to check if there were any implicitly in-progress items (uncommitted work).

## Suggestions
- The skill should specify how to handle uncommitted work from previous sessions — should it always be committed first, or should the user be consulted?
- The skill could benefit from a note about PROGRESS.md location flexibility, since not all projects will use `.claude/PROGRESS.md`.
- The priority scoring system in PROGRESS.md (the `[I:x U:x E:x = score]` format) could be documented in the skill or the progress template so future sessions understand the formula.
- When there is only one item in Next Up, the skill could explicitly acknowledge that the "judgment call" is trivial — there's only one option. The reasoning about "why this item" matters more when there are competing priorities.
