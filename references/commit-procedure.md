# Commit and .gitignore Procedure

Shared git-commit and `.gitignore` procedure for BRAINS phase-completion work. Both `/brains:nurture` (under `--scope phase-N`) and `/brains:document` cite this single source rather than duplicating the prose, to avoid behavioral drift.

When a skill owns phase-completion commit responsibilities, it MUST also:

1. **Ensure changes are committed.** Run `git status --porcelain`. If there are uncommitted changes, commit them atomically using conventional-commit messages (document mode uses a `docs:`-prefixed message). Group changes by conceptual unit; do not lump unrelated changes. Fold any `.gitignore` update from step 2 into the same atomic commit when it belongs to the same conceptual unit.

2. **Update `.gitignore`.** Identify files that should not be tracked:
   - Build artifacts (dist/, build/, target/, node_modules/, __pycache__/)
   - Secret or local-only configs (.env*, credentials.json, settings.local.json)
   - BRAINS runtime artifacts (docs/plans/.state/)

   Add any missing patterns to `.gitignore`. Commit.

3. **Reflect half-complete state in docs (if phase ended early).** If the teammate is running nurture during a pause/timeout, explicitly document in the nurture report which tasks are complete, which are in-progress, and which are blocked. Update any user-facing docs (README, architecture docs) affected by partial work to flag the incomplete state.
