---
name: nurture
description: This skill should be used when the user asks to "nurture", "review and fix", "improve code quality", "add tests", "fix remaining bugs", "polish the implementation", "check for completeness", or invokes "/brains:nurture". Reviews implementation for completeness, then fixes issues including bugs, missing features, and lack of tests. Supports --single (default), --parallel, and --debate modes for the review phase. When invoked by a phase-3 teammate with --scope phase-N, scopes the review to changes in that plan-phase, commits code and updates .gitignore, reflects any half-complete state in docs, and files follow-up beads tasks for the next phase or cleanup.
user-invocable: true
argument-hint: "[--single|--parallel|--debate] [--scope phase-N | all] [paths...]"
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent
---

# Nurture: Review, Test, and Refine

Review an implementation for completeness and quality, then systematically fix issues. Focus on bugs from incomplete code, missing features, lack of verifiable end-to-end tests, and other quality problems.

Set the plugin base path:
```bash
BRAINS_PATH="<base directory from header>/../.."
```

## Mode Behavior

Modes apply to the **review** phase. Fixing always happens locally.

| Mode | Flow |
|------|------|
| `--single` | Local LLM reviews independently. **(default)** |
| `--parallel` | Review locally, then send to council for additional review. |
| `--debate` | Multi-round review deliberation across LLMs. |

For `--parallel` and `--debate`, read and follow `$BRAINS_PATH/references/multi-llm-protocol.md`.

## Scope

The `--scope` flag controls what nurture reviews:

- `--scope phase-N` — review only files touched in the current plan-phase (use `git log --since` or the teammate's known commit range). File follow-up beads tasks labelled `brains:phase-<N+1>` if a next phase exists, else `brains:cleanup`. Invoked by phase-3 teammates.
- `--scope all` (default when invoked standalone) — review all recent changes per the classic behavior.

## Process

### 1. Gather Context

Identify what to review:

- **BRAINS outputs**: Check `docs/plans/` for research docs, ADRs (`docs/adr/`), and map/implement specs
- **Recent changes**: `git log --oneline -20` and `git diff main...HEAD --stat` to scope what was built
- **User scope**: If the user specified a scope, focus on those files/modules
- **Test coverage**: Check for existing test files, coverage reports

### 2. Conduct Review

Evaluate the implementation against these criteria:

**Completeness:**
- Does the code implement everything in the design spec?
- Are there TODO comments, placeholder implementations, or stub functions?
- Are all planned features present and functional?

**Correctness:**
- Are there logic errors or off-by-one mistakes?
- Do edge cases get handled?
- Does error handling follow the design spec?

**Test coverage:**
- Do end-to-end tests exist that verify the user-facing behavior?
- Are critical paths tested?
- Can the tests be run and do they pass?

**Code quality:**
- Does the code follow existing project patterns and conventions?
- Are there unnecessary abstractions or missing necessary ones?
- Is the code readable without excessive comments?

**Integration:**
- Does the new code integrate cleanly with existing code?
- Are interfaces respected?
- Are there breaking changes to existing functionality?

### 3. Council Review (if multi-LLM mode)

**Parallel mode:** After local review, send findings plus the code to the council:

```
Review this implementation for [project].

[Design spec summary]
[Files changed — list paths]

Focus on:
1. Bugs or logic errors
2. Missing features relative to the design spec
3. Test coverage gaps — especially missing E2E tests
4. Integration issues with existing code
5. Code quality concerns
```

Use `star-chamber review` (not `ask`) for code-focused review. Pass the changed files as review targets.

**Debate mode:** Run multi-round code review deliberation. Each round focuses on a different aspect (correctness, completeness, quality).

### 4. Compile Issue List

Consolidate all findings into a prioritized list:

| Priority | Category | Issue | File(s) | Fix |
|----------|----------|-------|---------|-----|
| P0 | Bug | [description] | [files] | [approach] |
| P1 | Missing feature | [description] | [files] | [approach] |
| P1 | Missing test | [description] | [files] | [approach] |
| P2 | Code quality | [description] | [files] | [approach] |

Present the list to the user. Get approval before fixing.

## Commit and .gitignore responsibilities (phase-3 teammate scope only)

When invoked with `--scope phase-N`, nurture MUST also:

1. **Ensure code is committed.** Run `git status --porcelain`. If there are uncommitted changes, commit them atomically using conventional-commit messages. Group changes by conceptual unit; do not lump unrelated changes.

2. **Update `.gitignore`.** Identify files that should not be tracked:
   - Build artifacts (dist/, build/, target/, node_modules/, __pycache__/)
   - Secret or local-only configs (.env*, credentials.json, settings.local.json)
   - BRAINS runtime artifacts (docs/plans/.state/)

   Add any missing patterns to `.gitignore`. Commit.

3. **Reflect half-complete state in docs (if phase ended early).** If the teammate is running nurture during a pause/timeout, explicitly document in the nurture report which tasks are complete, which are in-progress, and which are blocked. Update any user-facing docs (README, architecture docs) affected by partial work to flag the incomplete state.

### 5. Fix Issues

Work through the issue list in priority order:

- **P0 (Bugs):** Fix immediately. Run tests after each fix.
- **P1 (Missing features/tests):** Implement according to the design spec. Write E2E tests for missing coverage.
- **P2 (Code quality):** Fix only what materially affects readability or maintainability.

For each fix:
1. Make the change
2. Run relevant tests
3. Verify the fix doesn't break other functionality
4. Commit atomically with a descriptive message

### 6. Verify

After all fixes:

- Run the full test suite
- Verify E2E tests pass
- Check that all P0 and P1 issues are resolved
- Confirm no regressions were introduced

If tests fail, diagnose and fix before proceeding.

## Output

If significant changes were made, update the implementation plan or create a nurture report:

```markdown
# Nurture Report: [Topic]

## Review Summary
- Files reviewed: N
- Issues found: N (P0: X, P1: Y, P2: Z)
- Issues fixed: N
- Council providers: [if applicable]

## Issues Fixed
1. [description] — [commit hash]
2. ...

## Tests Added
1. [test description] — [file]
2. ...

## Remaining Items
[Any P2 issues deferred]
```

Write to `docs/plans/YYYY-MM-DD-<topic>-nurture.md` if a report is warranted. Commit to git.

When invoked with `--scope phase-N`, additionally:

- Report file: `docs/plans/<slug>-phase-<N>-nurture.md`
- Follow-up tasks filed to beads with label `brains:phase-<N+1>` (if next phase exists) or `brains:cleanup`.

Close the `Nurture: phase <N>` umbrella task on completion.

## Phase Transition

After nurture completes:

> "Nurture phase complete. [N] issues found, [M] fixed. Tests passing.
>
> Next steps:
> - `/brains:secure` — security review and hardening
> - `/brains:brains` — continue the full BRAINS pipeline"

## Additional Resources

- **`$BRAINS_PATH/references/multi-llm-protocol.md`** — shared multi-LLM invocation protocol
