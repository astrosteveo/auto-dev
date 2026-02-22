# User Notes

## Uncertainty
- The proposal preserves `std::function` for the factory type, which introduces one virtual call per component per entity. Entity creation is not a hot path (happens at world gen and template spawning, not per-frame), so this should be fine, but profiling would confirm.
- The `Relationships` factory ignores the `data` parameter (matching the original code which just does `entity.set(rel)` with defaults). If future JSON templates include relationship data, the factory would need updating.
- The skill says to move root-level PROGRESS.md to `.claude/PROGRESS.md` on next update. In a real execution this would be done, but it was skipped due to READ-ONLY constraints. The next real session should perform this move.

## Needs Human Review
- The proposed `register_component_factory()` is public, meaning any code can register factories. This is intentional (for mod extensibility), but the team should confirm this is the desired access level vs. a `friend`-based or init-only approach.
- The test strategy section suggests a test for factory extensibility, but `apply_component()` is private. The test would need to go through `create_entity()` with a synthetic DataRegistry entry, or a test-only wrapper. The team should decide which approach they prefer.

## Workarounds
- None. The skill worked as expected for this task.

## Suggestions
- The skill's Phase 1 location logic (check `.claude/PROGRESS.md` first, then root) worked correctly for this project where PROGRESS.md is at the root. The fallback path is important.
- For code-proposal tasks like this, the skill could benefit from a standardized "proposal output" format or template, similar to how it has a progress-template.md for PROGRESS.md.
