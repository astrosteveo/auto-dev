# User Notes

## Uncertainty
- The PROGRESS.md scoring system (I:Impact U:Urgency E:Effort = weighted score) is not formally documented anywhere -- I inferred the formula is (I + U) / E from the numbers. The skill itself doesn't define this scoring; it comes from the project's own conventions. If the formula is different, the relative ranking might change (though social memory would still likely win due to being the only non-deferred item).
- The social_system.cpp currently creates memory entries without setting the tick field (line 59: `{"social_interaction", other_id, 0, 1.0f}` -- tick is 0). The actual implementation of social memory AI would need to fix this first, which slightly increases the scope. I flagged this in the transcript under "what I would do."

## Needs Human Review
- The recommendation is clear-cut given the current backlog state (only one non-deferred item), but the user may have strategic reasons to prefer jumping to the building/placement system or adding new planned items. The skill says to "pick one and explain why" rather than presenting a menu, which I did -- but this is a case where the user might want to add new items to the backlog before proceeding.
- The uncommitted test files in the working tree should be reviewed/committed before starting new work. These appear to be complete and working (PROGRESS.md says "38 tests, 179 assertions") but they haven't been committed yet.

## Workarounds
- The input_files_dir did not exist and had to be created. This didn't affect execution since this eval has no staged input files, but the executor spec says to "list files in input_files_dir" which would have errored without creating it first.
- This is a READ-ONLY eval, so I could not actually execute Phase 4 (Update State) of the skill. I documented what I would do instead. This means the eval can only test the skill's analysis/recommendation quality, not its state management.

## Suggestions
- The skill's Phase 1 lookup order works well -- checking `.claude/PROGRESS.md` then root `PROGRESS.md` correctly found the file. The instruction to move it to `.claude/` on next update is good for standardization.
- The skill's "no task given" path (Phase 3) has clear, actionable criteria. The instruction to explain why deferred items aren't the pick is valuable -- it prevents the user from wondering about those items and provides full landscape context.
- Consider having the skill suggest committing uncommitted work as a pre-step when dirty working tree is detected, before making a "what's next" recommendation. Currently, the skill's Phase 2 (Reconcile State) checks git status but doesn't explicitly say to commit orphaned completed work.
