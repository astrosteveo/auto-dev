# User Notes

## Uncertainty
- The skill hardcodes `.claude/PROGRESS.md` as the expected location. This project uses `/PROGRESS.md` at the root. It is unclear whether the SessionStart hook would find it, inject it correctly, or silently fail. In this eval, I read it from the root directly, which worked, but a real session might behave differently depending on hook implementation.
- The uncommitted test files appear complete and correct based on the PROGRESS.md description, but I did not verify they compile or pass (READ-ONLY eval constraint). A real execution should run the test suite before committing.

## Needs Human Review
- The scoring system in "Next Up" uses `[I:x U:x E:x = score]` notation but the formula is not documented in PROGRESS.md or CLAUDE.md. It appears to be (Impact * Urgency) / Effort or similar. The single remaining item (Social memory AI decisions, score 2.33) is the obvious next pick regardless, but if more items are added, the scoring system should be documented so future sessions can prioritize correctly.
- The "Deferred" items have numbering that starts at 3 (not 1), suggesting items were removed or renumbered. This is cosmetic but could cause confusion.

## Workarounds
- Read PROGRESS.md from `/home/astrosteveo/Projects/working-title/PROGRESS.md` instead of `.claude/PROGRESS.md` as the skill instructs. The skill should support configurable or discoverable PROGRESS.md locations.
- The skill mentions the SessionStart hook injecting PROGRESS.md into context and says to "check your context before reading the file again." In this eval, there was no hook injection, so I read the file directly. This is the correct fallback behavior.

## Suggestions
- The skill should document a fallback search order for PROGRESS.md: check `.claude/PROGRESS.md` first, then `PROGRESS.md` at the root, then surface a clear message if neither exists. Currently, it only mentions `.claude/PROGRESS.md`.
- Phase 2 (Reconcile State) correctly identifies uncommitted work through `git status`, but the skill does not give explicit guidance on what to do about it. Should the orchestrator commit it? Ask the user? The skill should have a clear policy for discovered uncommitted work, especially since the Stop hook is supposed to auto-commit.
- The skill's Phase 4 says to update `.claude/PROGRESS.md` -- again hardcoding the path. If the project uses a different location, the skill should write to the same location it read from.
- The known issue about `apply_component()` has been sitting across multiple sessions (it was present before the test expansion work). Phase 2 says to flag items that have been "in progress" across multiple sessions -- known issues aren't quite the same as in-progress items, but stale known issues could benefit from similar flagging ("this has been known for N sessions, should it be prioritized?").
