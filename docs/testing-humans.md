# BRAINS Plugin — Human Test Walkthrough

These scenarios verify the v0.2.0 three-phase pipeline end-to-end. Run them against a scratch repository.

## Setup

```bash
mkdir -p /tmp/brains-test && cd /tmp/brains-test
git init
echo '{}' > package.json
git add package.json && git commit -m "initial"
```

Ensure Claude Code plugin is loaded with BRAINS v0.2.0 and the prerequisites are met (see README).

---

## Scenario 1: Happy path, tmux mode

**Starting state:** Fresh repo in /tmp/brains-test, inside a tmux session (run `tmux` first).

**Invocation:**

```
/brains:brains --parallel "add a /health endpoint to the Express app"
```

**Interaction script:**
- Phase 1 research subagent runs (~1-3 min). Confirm `docs/plans/*-research.md` exists.
- Questionnaire presents 2-4 questions. Answer them sensibly.
- ADR is presented. Accept with `y`.
- Phase 2 chains. Plan is presented (≤12 tasks, so flat list).
- Accept plan with `y`.
- Phase 3 launches. A tmux pane opens; observe the teammate work.
- Wait for the master pane to report "complete" for each phase and the final wrap-up.

**Assertions:**
- [ ] `docs/adr/` contains at least one ADR file with "MUST" or "SHOULD" in Requirements section
- [ ] `docs/plans/2026-04-15-*-map.md` exists with Slug, Mode, Branch header fields
- [ ] `bd list --label brains:topic:*` returns tasks, all closed
- [ ] `docs/plans/*-phase-1-nurture.md` exists
- [ ] `docs/plans/*-phase-1-secure.md` exists
- [ ] `docs/plans/*-wrap-up.md` exists
- [ ] The Express app has a working `/health` endpoint
- [ ] `git log --oneline` shows atomic, conventional commits

---

## Scenario 2: Happy path, agent-teams mode

**Starting state:** Fresh repo in /tmp/brains-test (re-run Setup), NOT inside a tmux session. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` set in settings.

**Invocation:**

```
/brains:brains --parallel "add a /health endpoint to the Express app"
```

**Interaction script:**
- Same flow as scenario 1 through phases 1 and 2: research runs, questionnaire presents, ADR accepted with `y`; plan presented, accepted with `y`.
- Phase 3 launches but uses agent-teams (no tmux pane). Observe via the agent-teams display.
- Observe `TeammateIdle` notifications when phase-1 nurture/secure and phase-2 nurture/secure complete.
- Wait for wrap-up to arrive in the master conversation.

**Assertions:**
- [ ] Same artefact assertions as scenario 1 (ADR, map, phase reports, wrap-up, working `/health`)
- [ ] No tmux panes were created during phase 3
- [ ] Output is functionally equivalent to scenario 1 (same ADR shape, same plan shape, same files produced)
- [ ] `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` path was taken (confirm via master pane log or progress messages mentioning agent-teams / `TeammateIdle`)
- [ ] `bd list --label brains:topic:*` returns tasks, all closed

---

## Scenario 3: ADR rejection at phase-1 gate

**Starting state:** Fresh repo in /tmp/brains-test (re-run Setup), tmux session active.

**Invocation:**

```
/brains:brains --parallel "add a /health endpoint"
```

**Interaction script:**
- Proceed through the research subagent and questionnaire normally; answer questions assuming Express.
- At the ADR gate, reject with a specific reason: `n` followed by "I actually want Koa, not Express" when prompted.
- Observe: master loops back to question generation, not to research (no new research subagent spawns).
- New questions arrive shaped by the rejection reason (asking about Koa middleware, compatibility, etc.).
- Answer and proceed; accept the second ADR with `y`.

**Assertions:**
- [ ] Only ONE research document exists under `docs/plans/*-research.md` (research was reused)
- [ ] No duplicate `*-research.md` files created with later timestamps
- [ ] Two versions of the ADR were considered — the final accepted ADR references Koa, not Express
- [ ] The rejection reason appears in the ADR's "Rationale" or "Alternatives Considered" section (or equivalent)
- [ ] Flow proceeded into phase 2 after the second ADR was accepted

---

## Scenario 4: Plan rejection at phase-2 gate

**Starting state:** Fresh repo in /tmp/brains-test (re-run Setup), tmux session active. Phase 1 completed and ADR accepted (either chain from a fresh `/brains:brains` run or start from phase 2 with an existing ADR).

**Invocation:** Implicit chain from phase 1 (`/brains:brains --parallel "..."`), OR explicit `/brains:map --parallel` with an ADR already present.

**Interaction script:**
- Plan is presented at the phase-2 gate (map).
- Reject with a specific reason: `n` followed by "split task 3 into two smaller tasks".
- Observe: `/brains:map` revises in place and re-presents (no return to phase 1, no new research).
- Accept the revised plan with `y`.

**Assertions:**
- [ ] `docs/plans/*-map.md` reflects the revision (e.g., task count increased by one; task 3 was split)
- [ ] No new `*-research.md` or new ADR was created during the revision loop
- [ ] Beads tasks were created only AFTER acceptance (the rejected plan did not create stray `bd` issues — verify via `bd list --label brains:topic:*` count matches the accepted plan)
- [ ] Flow proceeded into phase 3 after the second plan was accepted

---

## Scenario 5: Task fails once → re-groom → succeeds

**Starting state:** Fresh repo in /tmp/brains-test (re-run Setup), tmux session active. You'll run phase 3 and observe the failure/recovery path.

**Injection:** Before invocation, edit the user prompt seed so the first execution subagent for T-1.1 fails on its first attempt. Use a prompt instruction such as: *"For task T-1.1 only, on the first attempt, import a fictional library `not-a-real-package` and let the import fail. On the second attempt after re-groom, use the correct approach."*

**Invocation:**

```
/brains:brains --parallel "add a /health endpoint"
```

**Interaction script:**
- Proceed through phase 1 and phase 2 normally (accept ADR and plan).
- Phase 3 launches; teammate begins grooming, then execution.
- The first subagent for T-1.1 fails once (watch the teammate pane report the failure).
- Master reports "star-chamber re-groom triggered" (or equivalent message referencing the re-groom on failure).
- A second execution attempt for T-1.1 runs and succeeds.
- Subsequent tasks proceed normally through nurture and secure.

**Assertions:**
- [ ] `bd show <task-id-for-T-1.1>` shows ≥ 2 attempt records (via audit/comment log)
- [ ] The phase's nurture report (`docs/plans/*-phase-1-nurture.md`) references a re-groom event or star-chamber invocation for that task
- [ ] Task T-1.1 ultimately ends in `closed` status (`bd list --status closed`)
- [ ] Subsequent tasks proceeded normally (no cascading re-groom events)
- [ ] `docs/plans/*-wrap-up.md` exists and notes the re-groom

---

## Scenario 6: Task fails twice → needs-human → user resolves → auto-resume fires

**Starting state:** Fresh repo in /tmp/brains-test (re-run Setup), tmux session active.

**Injection:** Arrange for both attempts of T-1.1 to fail. Use a prompt instruction such as: *"For task T-1.1 only, on both the first AND second attempts (even after re-groom), fail with the same import error. On the third attempt after the user provides guidance, succeed."*

**Invocation:**

```
/brains:brains --parallel "add a /health endpoint"
```

**Interaction script:**
- Proceed through phases 1 and 2 normally.
- Phase 3 launches; first attempt for T-1.1 fails, re-groom triggers, second attempt also fails.
- Observe: master labels the task `brains:needs-human` (kind: `failure`) and posts a questionnaire to the master pane describing the failure.
- Provide guidance in the questionnaire: "use the standard `express` middleware rather than the fictional library".
- Observe: master updates beads with the guidance (new comment/annotation), relaunches a fresh teammate for the phase (tmux mode) or sends `SendMessage` (agent-teams mode).
- The new attempt succeeds; phase 3 continues to completion.

**Assertions:**
- [ ] Beads task briefly held the label `brains:needs-human` (inspect via `bd show <task-id>` history)
- [ ] Task metadata shows `needs-human-kind=failure` (visible in audit/comment history)
- [ ] After user response, task transitioned back to unblocked and eventually to `closed`
- [ ] Phase 3 did not halt — it resumed automatically after the user responded
- [ ] Master pane shows the questionnaire was posted and the user response was recorded
- [ ] `docs/plans/*-wrap-up.md` documents the needs-human resolution

---

## Scenario 7: Beads auto-init

**Starting state:** Fresh repo in /tmp/brains-test (re-run Setup) where `bd` CLI is installed but the repo has NOT been initialized — `bd status` in this directory returns a non-zero exit code / "not initialized" error. Tmux session active.

**Invocation:**

```
/brains:brains --parallel "simple health check"
```

**Interaction script:**
- Proceed through phase 1: research, questionnaire, ADR accepted with `y`.
- Phase 2 starts. Master emits the one-line announcement: *"Initializing beads for this repository (local mode)."*
- Observe no other init noise, no prompts for a remote — initialization happens silently in local mode.
- Plan is presented and accepted with `y`. Proceed into phase 3 if desired, or stop after confirming init.

**Assertions:**
- [ ] Before invocation, `bd status` fails; after phase 2 starts, `bd status` succeeds
- [ ] The initialization announcement appears EXACTLY ONCE in the master pane output
- [ ] No prompt asked the user to choose a beads backend (local mode was assumed)
- [ ] Tasks are created and labelled `brains:topic:*` after init (`bd list --label brains:topic:*` returns the plan's tasks)
- [ ] `.beads/` directory now exists in the repo

---

## Scenario 8: Missing tmux and missing agent-teams flag

**Starting state:** Fresh repo in /tmp/brains-test (re-run Setup). NOT inside a tmux session. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is unset. Phase 1 and phase 2 have already completed (ADR accepted, map accepted, beads tasks created) — you are about to run phase 3 standalone.

**Invocation:**

```
/brains:implement --parallel
```

**Interaction script:**
- Observe: phase 3 checks for a spawn mode, finds neither tmux nor agent-teams flag, and stops immediately.
- An install-instructions message appears in the master pane (covering both tmux install and how to set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`).
- No teammate is spawned; no tmux panes appear.

**Assertions:**
- [ ] Master pane output includes installation instructions for BOTH tmux AND agent-teams
- [ ] Exit is clean; no half-launched teammate artefacts (no stray `.brains/teammate-*` files, no orphan subagents)
- [ ] Beads state is unchanged (task count and statuses match pre-invocation state; no new comments or label changes)
- [ ] `/brains:implement --resume` (once a spawn mode is available) would pick up where you left off (verify by setting `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and re-running — phase 3 proceeds)

---

## Scenario 9: Star-chamber provider failure mid-phase

**Starting state:** Fresh repo in /tmp/brains-test (re-run Setup). `~/.config/star-chamber/providers.json` has THREE providers configured; exactly ONE of them has an intentionally invalid API key (e.g., `sk-invalid-test-key`) so that provider will fail when called. Tmux session active.

**Invocation:**

```
/brains:brains --parallel "add a /health endpoint"
```

**Interaction script:**
- Phase 1 begins. During question generation (star-chamber is invoked with `--parallel`), the failing provider errors out.
- Observe: the master pane logs the provider failure (e.g., "provider X failed: 401 unauthorized") but the pipeline does NOT halt.
- The other two providers continue and contribute to the question set / ADR draft.
- Proceed normally through the rest of phase 1, then phase 2, then phase 3.

**Assertions:**
- [ ] The failed provider is noted in at least one of: `docs/plans/*-research.md`, the ADR's "Council Input" section, or a phase nurture/secure report
- [ ] Pipeline did not halt at the provider failure; phase 1 completed with output from the remaining providers
- [ ] `docs/plans/*-wrap-up.md` summarizes the failure somewhere visible (e.g., "Note: provider X was unavailable during phase 1")
- [ ] Final artefacts (ADR, map, wrap-up) are otherwise complete and usable

---

## Cleanup

```bash
rm -rf /tmp/brains-test
```

To reset beads state or star-chamber overrides between scenarios, remove `.beads/` inside the scratch repo and restore `~/.config/star-chamber/providers.json` from backup.
