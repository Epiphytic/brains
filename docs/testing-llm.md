# BRAINS Plugin — LLM Test Protocol

Structured pass/fail scenarios for automated LLM-driven testing of the v0.2.0 three-phase pipeline. Each scenario has an exact invocation, an interaction script, and a checklist of assertions.

## Assertion Types

- `[FILE]` — a file must exist at a path (glob patterns allowed)
- `[GREP]` — a pattern must appear in a file
- `[CMD]` — a command must succeed (exit 0) or produce expected output
- `[STATE]` — beads must have a task in a given state with given labels

---

## Scenario 1: Happy path, tmux mode

**Setup:**
```bash
cd $(mktemp -d)
git init
echo '{}' > package.json
git add package.json && git commit -m "initial"
```

**Invocation:** `/brains:brains --parallel "add a /health endpoint"`

**Interaction script (LLM answers):**
- Q1 (architecture): pick the first recommended option
- Q2 (testing): pick "yes, include E2E tests"
- ADR review: accept
- Plan review: accept
- Phase 3 gate (if any): accept

**Assertions:**
- [FILE] docs/plans/*-research.md exists
- [FILE] docs/adr/*.md exists with ≥1 file
- [GREP] docs/adr/*.md matches `MUST|SHOULD|MAY`
- [FILE] docs/plans/*-map.md exists
- [GREP] docs/plans/*-map.md matches `^\*\*Slug:\*\*` and `^\*\*Mode:\*\*`
- [CMD] `bd list --label brains:topic:health-endpoint --status closed` returns ≥1 task
- [CMD] `bd list --label brains:topic:health-endpoint --status open` returns 0 tasks
- [FILE] docs/plans/*-phase-1-nurture.md exists
- [FILE] docs/plans/*-phase-1-secure.md exists
- [FILE] docs/plans/*-wrap-up.md exists
- [GREP] docs/plans/*-wrap-up.md matches `paused: false`

---

## Scenario 2: Happy path, agent-teams mode

**Setup:** Same as scenario 1 plus `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and ensure not inside a tmux session (`unset TMUX`).

**Invocation:** `/brains:brains --parallel "add a /health endpoint"`

**Interaction script:** Same answers as scenario 1.

**Assertions:**
- [FILE] docs/plans/*-research.md exists
- [FILE] docs/adr/*.md exists with ≥1 file
- [FILE] docs/plans/*-map.md exists
- [FILE] docs/plans/*-phase-1-nurture.md exists
- [FILE] docs/plans/*-phase-1-secure.md exists
- [FILE] docs/plans/*-wrap-up.md exists
- [CMD] `tmux list-panes` returns error or zero panes (no tmux panes spawned)
- [GREP] docs/plans/*-wrap-up.md matches `paused: false`
- [CMD] Master pane log mentions `agent-teams` or `TeammateIdle` somewhere (spawn mode detection output)
- [CMD] `bd list --label brains:topic:health-endpoint --status closed` returns ≥1 task
- [CMD] `bd list --label brains:topic:health-endpoint --status open` returns 0 tasks

---

## Scenario 3: ADR rejection at phase-1 gate

**Setup:** Same as scenario 1.

**Invocation:** `/brains:brains --parallel "add a /health endpoint"`

**Interaction script:**
- Answer questions normally (assume Express).
- ADR review (first): reject with reason "use Koa instead of Express"
- Questions regenerate — answer them (now shaped by Koa context).
- ADR review (second): accept.
- Plan review: accept.

**Assertions:**
- [CMD] Only ONE `docs/plans/*-research.md` exists (research reused — count via `ls docs/plans/*-research.md | wc -l` equals 1)
- [GREP] The accepted ADR in docs/adr/*.md matches `Koa`
- [GREP] The rejected ADR reason appears in phase-1 nurture report or wrap-up log (`docs/plans/*-phase-1-nurture.md` or `docs/plans/*-wrap-up.md` matches `Koa` or the rejection reason)
- [STATE] No beads task has a label implying a duplicate research run (no `brains:research-*` labels beyond the single initial run)
- [FILE] docs/plans/*-map.md exists (flow proceeded to phase 2)

---

## Scenario 4: Plan rejection at phase-2 gate

**Setup:** Same as scenario 1. Phase 1 already completed and ADR accepted (chain from a fresh `/brains:brains` run, or start from phase 2 with an existing ADR).

**Invocation:** Continue from phase 1, or `/brains:map --parallel` explicitly.

**Interaction script:**
- Plan review (first): reject with reason "split task 3 into two"
- Plan review (second, revised): accept

**Assertions:**
- [CMD] `docs/plans/*-map.md` task count > original (revision took effect — count task headings after revision exceeds initial count)
- [CMD] Only the accepted plan generated beads tasks — `bd list --label brains:topic:*` count matches the revised plan's task count (no stray issues from the rejected plan)
- [FILE] No duplicate map file variants exist (the map is overwritten in place — `ls docs/plans/*-map.md | wc -l` equals 1)
- [CMD] No new `*-research.md` or new ADR was created during the revision loop (`ls docs/plans/*-research.md | wc -l` equals 1)
- [STATE] Flow proceeded into phase 3 after the second plan was accepted (beads tasks exist with `brains:ready-for-grooming` or equivalent ready state)

---

## Scenario 5: Task fails once → re-groom → succeeds

**Injection:** Before invocation, append to the user prompt: *"For task T-1.1 only, on the first attempt, import a fictional library `not-a-real-package` so the import fails. On the second attempt after re-groom, use the correct approach."* This instructs the execution subagent to fail the first attempt and succeed on the second.

**Setup:** Same as scenario 1.

**Invocation:** `/brains:brains --parallel "add a /health endpoint"` (proceed through all phases).

**Interaction script:** Accept gates normally. No user intervention during failure — the re-groom is automatic.

**Assertions:**
- [GREP] docs/plans/*-phase-1-nurture.md matches `re-groom` or `star-chamber` (acknowledging the re-groom occurred)
- [CMD] `bd show <task-id-for-T-1.1>` shows ≥2 attempt records in the audit/comment log
- [STATE] T-1.1 ends in `closed` state (`bd list --status closed` includes T-1.1)
- [STATE] No task retains `brains:needs-human` label at end of run (`bd list --label brains:needs-human` returns 0 tasks)
- [FILE] docs/plans/*-wrap-up.md exists
- [GREP] docs/plans/*-wrap-up.md matches `re-groom` or references the single-failure recovery
- [STATE] Subsequent tasks proceeded normally (no cascading re-groom events — only T-1.1 shows multiple attempts)

---

## Scenario 6: Task fails twice → needs-human → user resolves → auto-resume

**Injection:** Before invocation, append to the user prompt: *"For task T-1.1 only, on both the first AND second attempts (even after re-groom), fail with the same import error referencing `not-a-real-package`. On the third attempt after the user provides guidance, succeed using the `express` package."* This ensures both auto-attempts fail and forces the needs-human path.

**Setup:** Same as scenario 1.

**Invocation:** `/brains:brains --parallel "add a /health endpoint"`

**Interaction script:**
- Proceed through phase 1 and phase 2 (accept ADR, accept plan).
- Phase 3 launches; first attempt for T-1.1 fails, re-groom triggers, second attempt also fails.
- When master posts the needs-human questionnaire, respond with guidance: "use the standard `express` package instead of the fictional one"
- Allow pipeline to resume automatically.

**Assertions:**
- [STATE] T-1.1 briefly held `brains:needs-human` label (visible in `bd show <task-id>` history)
- [GREP] The task's beads metadata/comments contain `needs-human-kind=failure`
- [STATE] T-1.1 final state is `closed`
- [CMD] `bd show <task-id-for-T-1.1>` audit log shows the user-guidance comment (matches `express`)
- [GREP] docs/plans/*-wrap-up.md matches `paused: false` (auto-resumed successfully)
- [GREP] docs/plans/*-wrap-up.md documents the needs-human resolution (matches `needs-human` or equivalent)
- [STATE] Phase 3 completed — all other tasks in `closed` state (`bd list --label brains:topic:* --status open` returns 0)

---

## Scenario 7: Beads auto-init

**Setup:**
```bash
cd $(mktemp -d)
git init
echo '{}' > package.json
git add package.json && git commit -m "initial"
# Ensure `bd` is installed but NOT initialized for this repo
# Pre-check: `bd status` in this directory MUST fail before invocation
```

**Invocation:** `/brains:brains --parallel "simple health check"` (proceed through phase 1, accept ADR; continue into phase 2)

**Interaction script:** Accept gates normally. No backend prompt should appear — local mode is assumed.

**Assertions:**
- [CMD] Before invocation, `bd status` fails (non-zero exit); after phase 2 starts, `bd status` succeeds
- [GREP] Master pane log contains the initialization announcement `Initializing beads for this repository (local mode).` — and matching grep count equals exactly 1 (`grep -c` returns 1)
- [STATE] ≥1 beads task with `brains:topic:*` label exists after init (`bd list --label brains:topic:*` returns ≥1)
- [FILE] `.beads/` directory now exists in the repo
- [CMD] No prompt asked the user to choose a backend (verify master pane log contains no `remote` or `backend` choice prompt during init)

---

## Scenario 8: Missing tmux and missing agent-teams flag

**Setup:**
- Fresh repo (same bootstrap as scenario 1).
- Not inside a tmux session (`unset TMUX`).
- `unset CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`.
- Phase 1 and phase 2 already completed successfully (ADR accepted, map accepted, beads tasks created).

**Invocation:** `/brains:implement --parallel`

**Interaction script:** N/A — command should exit early with install instructions.

**Assertions:**
- [GREP] Output contains installation instructions for tmux AND instructions for enabling `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- [CMD] Exit is clean (exit code reflects early termination, no dangling teammate pane or spawned subagent)
- [STATE] No beads tasks changed status during this invocation (compare `bd list --label brains:topic:*` output before and after — identical)
- [FILE] No new completion marker files were created under `docs/plans/.state/` (glob returns same set before and after)
- [FILE] No stray `.brains/teammate-*` files exist
- [CMD] After setting `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and re-running `/brains:implement --resume`, phase 3 proceeds (resume capability intact)

---

## Scenario 9: Star-chamber provider failure mid-phase

**Setup:**
- Configure `~/.config/star-chamber/providers.json` with three providers.
- Set exactly one provider's API key to an invalid value (e.g., `sk-invalid-test-key`) so it will fail when called.
- Fresh repo (same bootstrap as scenario 1).
- Tmux session active.

**Invocation:** `/brains:brains --parallel "add a /health endpoint"`

**Interaction script:** Accept gates normally. The failing provider should error during question generation (`star-chamber ask --parallel`) but the pipeline must not halt.

**Assertions:**
- [GREP] At least one of `docs/plans/*-research.md`, `docs/adr/*.md`, or `docs/plans/*-phase-1-nurture.md` mentions the failed provider (by name or as `failed provider` / `unavailable`)
- [GREP] docs/plans/*-wrap-up.md references the provider failure (matches `provider` and `fail` / `unavailable`)
- [CMD] Pipeline completed — `docs/plans/*-wrap-up.md` exists
- [GREP] docs/plans/*-wrap-up.md matches `paused: false`
- [STATE] No tasks stuck in `brains:needs-human` state (`bd list --label brains:needs-human` returns 0)
- [FILE] Final artefacts (ADR, map, wrap-up) all present and non-empty

---

## Cleanup

```bash
# From the scratch directory used in Setup
rm -rf .beads docs/plans docs/adr
# Or delete the whole scratch directory
```

To reset star-chamber overrides between scenarios, restore `~/.config/star-chamber/providers.json` from backup.
