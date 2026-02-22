# User Notes

## Uncertainty
- The proposal preserves the exact deserialization logic from each if/else branch. I verified this by reading the code line-by-line, but a diff tool should be used during actual implementation to confirm byte-for-byte equivalence of the lambda bodies vs. the original branches.
- The `register_applicator()` method is private. If mods need to register custom C++ components with applicators in the future, the API would need to be made public or a friend mechanism added. The proposal mentions this as a future extension but does not implement it.
- Two component schemas (`resource_node`, `terrain_info`) are missing from `data/base/components/`. This is unrelated to the apply_component() fix but represents a minor data inconsistency.

## Needs Human Review
- The decision to use `std::function` over raw function pointers or template-based dispatch. `std::function` has a small allocation overhead for captures, but none of the registered lambdas actually capture anything, so most implementations will use small-buffer optimization. If performance profiling reveals this as a concern (unlikely -- entity creation is not a hot path), raw function pointers could replace `std::function`.
- Whether the `ComponentApplicator` type alias should be public or kept private. The proposal makes it public for documentation clarity, but it could be private if the API surface should remain minimal.

## Workarounds
- None. The skill executed cleanly for this task.

## Suggestions
- The skill's Phase 1 says to move PROGRESS.md from project root to `.claude/PROGRESS.md`. For this project, PROGRESS.md at the root may be intentional (it is tracked in git and visible to contributors). The skill should perhaps check for a `.claude/` directory or CLAUDE.md preference before automatically relocating it.
- The known issues section in the PROGRESS.md template could benefit from a structured format (like the priority scoring used in Next Up) to help future sessions triage multiple issues.
