# User Notes

## Uncertainty
- The skill references `.claude/PROGRESS.md` but this project stores PROGRESS.md at the repository root (`/home/astrosteveo/Projects/working-title/PROGRESS.md`). I adapted to the actual location. If executing for real, the Phase 4 state update would need to write to the root path, not `.claude/PROGRESS.md`.
- The `component_map_` member in `World` is populated by `register_component()` but never used in any visible code path. It is unclear whether external code (mods, Lua scripts) calls `register_component()` -- this should be verified before removing the member. The `register_component()` method itself could be retained as a thin wrapper around `register_hydrator()` for backward compatibility.
- The `schema_map_` is similarly populated but unused. The proposed fix retains it for potential future schema validation but does not integrate it.

## Needs Human Review
- The proposed fix makes `register_hydrator()` a public method to enable future mod-defined components. This is a design decision that should be confirmed -- making it public changes the World class's API surface. If mod extensibility is not desired yet, it could remain private with the hydrators registered only in `init()`.
- The `Renderable` hydrator lambda is the longest at ~25 lines due to the array/field format handling for colors. If this pattern recurs for future components, a helper function for color deserialization might be cleaner, but that is a separate concern from the refactoring itself.

## Workarounds
- Since this is a READ-ONLY eval, I documented the proposed changes as a written proposal (`proposed_fix.md`) rather than editing the source files directly. The transcript captures the full analysis and what would be done if executing for real.

## Suggestions
- The skill's Phase 1 should handle the case where `PROGRESS.md` is at the project root rather than `.claude/PROGRESS.md`. A search-based approach (check both locations) or a configurable path would make the skill more robust across projects.
- The skill correctly guided me to assess scope before acting and to avoid spinning up teams for a focused task. The Phase 3 scope assessment was directly useful for this eval.
- The skill's state reconciliation step (Phase 2) caught that there are uncommitted changes in the working tree -- good context that would matter for a real execution.
