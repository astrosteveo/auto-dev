# User Notes

## Uncertainty
- The PROGRESS.md scoring system (I:3 U:4 E:3 = 2.33) uses Impact, Urgency, and Effort metrics but the formula/weighting is not documented anywhere in the skill or PROGRESS.md itself. I interpreted higher scores as higher priority, which aligns with the ordering.
- The "Deferred" section numbering starts at 3 (skipping 1-2), suggesting items were renumbered when "Expand test coverage" was completed and removed. This is cosmetic but could confuse future readers.
- It's unclear whether the social_system.cpp memory entries (line 59: `{"social_interaction", other_id, 0, 1.0f}`) include the `tick` field properly — the `0` for tick means these memories have no timestamp, which would affect recency-weighted scoring in the planned social memory feature. This may need to be fixed as a prerequisite for the social memory AI decisions feature.

## Needs Human Review
- The uncommitted test files (test_clock.cpp, test_data_registry.cpp, test_pathfinding.cpp, test_tile_map.cpp, test_utility_ai.cpp) were not read during this eval. Their quality and correctness should be verified before committing.
- The deferred items' explanations come from the PROGRESS.md itself and my analysis. The user should confirm that the building/placement and save/load systems are correctly prioritized below social memory.

## Workarounds
- The output directory path in the eval spec uses `/with_skill/` but the filesystem has `{with_skill/`. I created the non-braced path as specified in the eval instructions and wrote outputs there.
- This is a read-only eval so no actual state changes were made. All actions that would modify files (commit, move PROGRESS.md, update PROGRESS.md) are documented in the transcript as what WOULD happen.

## Suggestions
- The skill mentions a SessionStart hook that injects PROGRESS.md into context, but this project has no `.claude/` directory and PROGRESS.md is at the root. The skill's fallback behavior (check root, then move on next update) is correct, but it would be helpful if the skill also mentioned creating `.claude/` if it doesn't exist.
- The PROGRESS.md template in `references/progress-template.md` doesn't include scoring notation (I:X U:Y E:Z = score) that the actual PROGRESS.md uses. Documenting this scoring system in the template would help consistency.
- The skill's Phase 3 "no task given" section says to explain why deferred items are deferred. The existing PROGRESS.md partially does this (mentions dependencies, scope) but could be more explicit. The skill update mentioned in the eval context ("explain why deferred items are deferred") is a good improvement.
