# User Notes

## Uncertainty
- The test expansion work (5 new test files) appears complete based on the diff and file listing, but I did not run the test suite to verify all 38 tests pass. In a real execution, I would run `./build/tests/wt_tests` to confirm.
- The `.cache/` and `build/` directories appear in git status as untracked. I assumed these are build artifacts and should not be committed, but I did not verify whether a `.gitignore` exists or whether these are intentionally tracked.
- PROGRESS.md claims 179 assertions but I did not verify this count by running the tests.

## Needs Human Review
- The decision to prioritize "Social memory AI decisions" as the next task is based on the project's own PROGRESS.md prioritization. The user may have different priorities in mind -- the prompt was "figure out what's going on," not "start the next task."
- Whether to move PROGRESS.md to `.claude/PROGRESS.md` is a project convention decision. The skill says to do it, but the project may have reasons for keeping it at the root (e.g., visibility, other tooling).

## Workarounds
- This was a read-only eval, so the skill's Phase 4 (Update State) could not be executed. In a real execution, I would commit the uncommitted work, move PROGRESS.md, and update it.
- The input directory was empty (no staged input files), which is expected for this type of "pick up the project" prompt.
- The directory structure for the eval workspace had curly braces in directory names (`{with_skill` and `inputs}`, `outputs}`), which did not match the user-provided paths. I created clean directories matching the user's specified paths.

## Suggestions
- The skill could benefit from a "read-only mode" or "dry-run" flag for scenarios where the user just wants a status report without any state modifications.
- The skill's Phase 1 mentions checking if the SessionStart hook already injected PROGRESS.md into context, but there is no programmatic way to detect this from within the skill execution. A convention or marker would help.
- Adding a `.gitignore` entry for `.cache/` and `build/` would clean up the `git status` output that the skill relies on for state reconciliation.
