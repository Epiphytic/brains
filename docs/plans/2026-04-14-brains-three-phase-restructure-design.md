# Design: BRAINS Three-Phase Restructure

**Date:** 2026-04-14 (revised 2026-04-15 after star-chamber review)
**Status:** Draft — awaiting user review
**Target version:** v0.2.0

## Problem Statement

The current BRAINS plugin exposes six user-invocable skills (`storm`, `research`, `architect`, `implement`, `nurture`, `secure`) plus a `brains` orchestrator that chains them with user gates. In practice, the first three skills (brainstorm, research, architect) are tightly coupled — research informs brainstorming, which informs architecture — and splitting them into three gated steps creates context loss and user friction without providing real optionality. The last three (implement, nurture, secure) are also coupled, but they need a different execution model: they operate on code and benefit from running in fresh Claude Code contexts with real task tracking, not as a linear pipeline of ad-hoc skill invocations.

Additionally, the current model runs nurture and secure once at the very end of a project. For anything beyond a tiny change, this is too late — quality issues compound across phases, and finding them at the end means expensive rework.

## Goals

1. Collapse the brainstorm → research → architect pipeline into a single interactive skill that drives a subagent-researched, multi-LLM-reviewed questionnaire to an RFC 2119 ADR.
2. Introduce a distinct planning phase that produces a high-level, phased task list (not implementation specifics) with beads-based tracking.
3. Restructure the implementation phase around per-plan-phase teammate Claude Code instances, with nurture and secure running inside each plan-phase rather than once at the end.
4. Preserve `nurture` and `secure` as standalone-invocable skills so they can be used on any codebase, not just BRAINS-initiated work.
5. Adopt Claude Code's experimental agent teams feature as the preferred teammate spawn mechanism when available, falling back to tmux otherwise.
6. Build in first-class failure recovery: single failures trigger a star-chamber re-groom; repeated failures hand the problem back to the user via a short in-context questionnaire; resume is automatic when the user unblocks.

## Non-Goals

- Preserving backward compatibility with v0.1.0 command names beyond `nurture` and `secure`. The plugin is at v0.1.0 with no external dependencies; a clean break is cheaper than parallel code paths.
- Testing star-chamber output quality or nurture/secure finding accuracy. Both are provider- and prompt-dependent; validated by human walkthroughs rather than automated checks.
- Updating `assets/brains-lifecycle.jpeg` as part of v0.2.0. Nice to have, not blocking.

## Skills After Restructure

| Skill | Command | User-invocable | Default mode | Purpose |
|-------|---------|:---:|:---:|---|
| `setup` | `/brains:setup` | yes | — | Unchanged entry point; extended defaults for beads and teammate spawn-mode detection. |
| `suggest` | *(auto)* | yes (auto) | — | Minor rewrite — recommends the three-phase flow instead of six phases. |
| `brains` | `/brains:brains` | yes | `--parallel` | **New.** Phase 1 — research → questions → interactive Q&A → ADR(s). Chains into phase 2 via user gate. |
| `map` | `/brains:map` | yes | `--parallel` | **New.** Phase 2 — high-level plan generation + beads task creation with nurture/secure tasks per plan-phase. |
| `implement` | `/brains:implement` | yes | `--parallel` | **Rewritten.** Phase 3 — launches a teammate Claude Code instance per plan-phase; master observes beads state and advances sequentially. |
| `nurture` | `/brains:nurture` | yes | `--single` | **Kept** with minor edits to support subagent invocation and phase-scoped review. |
| `secure` | `/brains:secure` | yes | `--single` | **Kept** with the same edits as `nurture`. |
| `storm` | — | — | — | **Deleted.** Absorbed into `/brains:brains`. |
| `research` | — | — | — | **Deleted.** Absorbed into `/brains:brains`. |
| `architect` | — | — | — | **Deleted.** Absorbed into `/brains:brains`. |

### Output File Conventions

| Phase | Output | Location |
|---|---|---|
| Phase 1 | Subagent research notes | `docs/plans/YYYY-MM-DD-<topic>-research.md` |
| Phase 1 | ADR(s), RFC 2119 language, mermaid diagrams when warranted | `docs/adr/YYYY-MM-DD-NNN-<title>.md` |
| Phase 2 | High-level plan | `docs/plans/YYYY-MM-DD-<topic>-map.md` |
| Phase 2 | Work items | beads (preferred) or TaskCreate fallback |
| Phase 3 | Per-phase nurture and secure reports | `docs/plans/YYYY-MM-DD-<topic>-phase-N-nurture.md`, `-phase-N-secure.md` |
| Phase 3 | Final wrap-up | `docs/plans/YYYY-MM-DD-<topic>-wrap-up.md` |

### Pipeline Chain

```
/brains:brains
    │
    │  user accepts ADR (or rejects → loop back in phase 1)
    ▼
/brains:map
    │
    │  user approves plan (or rejects → revise within phase 2)
    ▼
/brains:implement
    │
    │  per plan-phase: launch teammate, wait, advance
    ▼
final cleanup teammate (or master-written wrap-up if no cleanup work)
```

Mode inheritance is strict: the mode flag passed to `/brains:brains` becomes the default for `/brains:map` and `/brains:implement` when the pipeline chains through the gates. At each gate the user may override with `--single`, `--parallel`, or `--debate`.

## Phase 1 — `/brains:brains`

### Flow

1. Parse arguments (mode, topic). Default mode: `--parallel`.
2. **Initial research (subagent).** Spawn a research subagent scoped to the user's prompt. It investigates up-to-date dependency versions, deprecated APIs, idiomatic patterns, and prior art using Glob, Grep, WebSearch, WebFetch, and context7. Output: `docs/plans/YYYY-MM-DD-<topic>-research.md` (committed to git).
3. **Question generation** (mode-dependent):
    - `--single`: a subagent generates a set of 2-4 questions with explicit pros and cons for each, informed by the prompt and research.
    - `--parallel`: both a subagent and the star-chamber generate candidate question sets; the main LLM merges them and removes duplicates.
    - `--debate`: the subagent and star-chamber debate the question set across the configured number of rounds (default 2) or until convergence.
4. **Interactive questionnaire (main LLM ↔ user).** For each question: present it with pros and cons, accept the user's answer, then adapt the remaining question set based on new information. If an answer contradicts a research finding, introduces a new architectural dimension, or renders remaining questions interdependent in unforeseen ways, re-engage the star-chamber for question review and optionally spawn a fresh research subagent for the new dimension. **Visual companion:** if any question would be clearer with a visual (layout comparison, state-machine mockup, component diagram), offer the browser-based visual companion (once per session, then per-question decision). Use the terminal for conceptual questions, the browser for visual ones. The companion server was inherited from the former `storm` skill and is kept in place under `skills/brains/scripts/`.
5. **Architecture synthesis.** Produce the full architecture with up-to-date standards. For key frameworks, APIs, and libraries, version specification is a recommendation (SHOULD, not MUST): prefer MAJOR.MINOR for semver libraries; use the library's native version scheme for non-semver (e.g., calendar versioning, Rails release lines). This is provenance, not a lock — implementation may bump versions as needed.
6. **Architecture review** (mode-dependent):
    - `--single`: skip; present to user.
    - `--parallel`: star-chamber reviews the architecture; integrate feedback with user approval.
    - `--debate`: star-chamber debates the architecture across rounds.
7. **ADR generation.** Produce one or more ADRs in `docs/adr/` using RFC 2119 MUST/MUST NOT/SHOULD/SHOULD NOT/MAY language in the requirements section. Include a mermaid diagram if the ADR has three or more components with two or more relationships, or at least one state machine.
8. **User gate.**
    - *Accept:* prompt "Implement this ADR?" and chain into `/brains:map` with inherited mode.
    - *Reject:* collect the rejection reason as free-form text. Loop back to step 3. The rejected ADR and rejection reason are added to context for the next question-generation pass; initial research from step 2 is reused (no re-run).

### ADR Structure

```markdown
# ADR-NNN: <Title>

**Date:** YYYY-MM-DD
**Status:** Accepted
**Decision makers:** <user + providers consulted>

## Context
<Why this decision is needed>

## Decision
<Prose summary of what was decided — the high-level choice and its shape>

## Requirements (RFC 2119)
<Testable MUST/SHOULD/MAY statements derived from the decision; these are what the implementation is verified against>
- The system MUST <requirement>.
- The system SHOULD <requirement>.
- The system MAY <requirement>.

## Rationale
<Why this option over alternatives>

## Alternatives Considered
### <Alternative 1>
- Pros: ...
- Cons: ...
- Why rejected: ...

## Assumed Versions (SHOULD)
- <framework/lib>: X.Y — in whatever versioning scheme the library uses
- <api>: X.Y

## Diagram
<mermaid block, if warranted>

## Consequences
<What changes as a result>

## Council Input
<Summary of star-chamber feedback, when applicable>
```

## Phase 2 — `/brains:map`

### Flow

1. Parse arguments. Default mode: `--parallel` (inherited if chained from phase 1).
2. **Derive topic slug** from the topic argument (kebab-case, lowercase). Example: *"add a health-check endpoint"* → `health-check-endpoint`.
3. **Branch offer.** If the current branch is one of the configured base branches (default: `main`, `master`, `develop`), offer to create `brains/<slug>` and switch to it. If the user is already on a non-base branch, use it. If the user declines, continue on the current branch with a one-line warning that BRAINS tasks will be labelled with the current branch name.
4. **Load inputs.** All accepted ADRs from phase 1 and the research document. **Codebase exploration policy:** if phase 1 produced the research document less than 1 hour ago and no git commits landed on the current branch since then, reuse phase 1's exploration — skip re-exploring. Otherwise (stale research, or commits landed since — common when branches have multiple writers), spawn a refresher subagent to re-explore the codebase and note any drift from the ADR's assumptions. Significant drift is surfaced to the user before proceeding; minor drift is noted in the plan document.
5. **High-level plan generation (subagent).** Prompt the subagent to produce a task list that sketches what needs to be built without implementation specifics (intentionally stub-level — easier to clean up if re-architecture becomes necessary in phase 3), identifies dependencies between tasks, and — if there are more than approximately 12 tasks — groups them into plan-phases where each phase is independently testable. Output: `docs/plans/YYYY-MM-DD-<slug>-map.md` (overwrites any existing map for this slug — see *Plan Document Structure* below).
6. **Plan review** (mode-dependent):
    - `--single`: skip.
    - `--parallel`: star-chamber reviews task ordering, sizing, coverage, and phasing; integrate feedback.
    - `--debate`: star-chamber debates the plan across rounds.
7. **User gate.**
    - *Reject:* revise in place, re-present. Stay within phase 2.
    - *Accept:* proceed to task creation and chain into `/brains:implement`.
8. **Task tracker selection.** Beads is the authoritative task tracker whenever it is available. Selection logic:
    - **Beads installed and initialized:** use it.
    - **Beads installed but uninitialized:** run `bd init --local` automatically and announce: *"Initializing beads for this repository (local mode)."* No prompt.
    - **Beads unavailable, agent-teams mode active:** fall back to agent-teams' built-in task list. Announce to the user: *"beads is not installed. Falling back to the agent-teams task list. Cross-session recovery, dependency queries, and label filtering are degraded in this mode. Install beads for the full experience."*
    - **Beads unavailable, tmux mode:** fall back to `TaskCreate` / `TaskUpdate`. Same one-line awareness note as above, adjusted for the tracker.
9. **Task creation.** For each plan-phase:
    - Create a beads task per plan-item with labels `brains:topic:<slug>`, `brains:ready-for-grooming`, `brains:phase-N`, and any domain labels inferred from the ADR.
    - Wire inter-task dependencies from the plan.
    - Create a `Nurture: phase N` beads task, labelled `brains:topic:<slug>` and `brains:phase-N`, blocked by all phase-N implementation tasks.
    - Create a `Secure: phase N` beads task, labelled `brains:topic:<slug>` and `brains:phase-N`, blocked by the `Nurture: phase N` task.
    - For the final plan-phase, create a `Cleanup` beads task, labelled `brains:topic:<slug>` and `brains:cleanup`, blocked by all phase-N secure tasks.
10. **Re-architecture cleanup (only on re-architecture-triggered re-run).** If phase 2 is being re-run because phase 3 escalated a `needs-human-kind=re-architecture` (see phase 3 failure flow), before creating new tasks, find all beads tasks with the matching `brains:topic:<slug>` label and a creation timestamp before the new ADR's date, and close them with a `brains:superseded` label. This preserves audit history without polluting the active task list. Implementation work already completed on superseded tasks remains in git history; what to do with it is up to the new plan.

### Plan Document Structure

The plan document is regenerated each time phase 2 runs (including on re-architecture). Existing plan documents at the same path are overwritten — this is the tracker, not the archive. ADRs, research notes, and per-phase nurture/secure reports are immutable by contrast and must not be overwritten.

```markdown
# Plan: <topic>

**Slug:** <topic-slug>
**ADRs:** <list of paths>
**Research:** <research doc path>
**Mode:** <--single | --parallel | --debate>   ← persisted for --resume
**Branch:** <branch name>

## Overview
<one-paragraph summary of what this plan accomplishes>

## Tasks (if ≤12) / Phases (if >12)

### Phase 1: <theme>
- [ ] **T-1.1**: <title>
  - Depends on: <none | T-X.Y, ...>
  - Acceptance: <one-line verifiable check>
- [ ] **T-1.2**: ...

### Phase 2: <theme>
...
```

`/brains:implement --resume` reads the `Mode` line to restore the pipeline's mode. A CLI flag on `--resume` (e.g., `/brains:implement --resume --single`) overrides the persisted value for the resumed session.

## Phase 3 — `/brains:implement`

### Master-side flow

1. Parse arguments. Default mode: `--parallel` (inherited). Load the plan document and ADRs.
2. **Prerequisite checks.**
    - Teammate spawn mode (see below): agent-teams if enabled, else tmux, else stop with install instructions.
    - Beads preferred; `TaskCreate` fallback.
3. **Enumerate plan-phases** from beads labels (`brains:phase-1`, `brains:phase-2`, ..., `brains:phase-N`, `brains:cleanup`), scoped to the current pipeline via `brains:topic:<slug>`. Slug is read from the `Slug:` field in the map document.
4. **For each plan-phase in order:**
    1. Launch the teammate with its initial prompt (ADR paths, plan path, phase label, mode, completion marker path, behavioral constraints).
    2. Wait. Poll beads state (every ~15s) plus completion marker file. Surface one-line progress updates when state changes.
    3. Teammate completes → advance.
5. **Final cleanup teammate.** Launched after the last plan-phase if any `cleanup`-labelled tasks exist. The cleanup teammate runs the standard groom → execute → nurture → secure flow over cleanup-labelled tasks and writes the wrap-up report. If no cleanup tasks exist, master writes the wrap-up report directly and no cleanup teammate is launched.
6. **Wrap-up.** Master reads the wrap-up report (whether written by the cleanup teammate or by itself), summarizes it to the user, and closes any remaining teammate panes.

### Teammate-side flow (identical in both spawn modes)

1. Read ADRs, plan, and mode from the initial prompt.
2. **Grooming (single subagent).** For all tasks matching `brains:topic:<slug>` + `brains:phase-N` + `brains:ready-for-grooming`, research codebase and external docs as needed, flesh out descriptions, acceptance criteria, and implementation notes. If grooming surfaces new tasks, add them to beads with the same topic and phase labels. On completion, swap `brains:ready-for-grooming` for `brains:groomed`.
3. **Execution (fresh subagent per task).** In dependency order, spawn a fresh subagent per task with: task description, relevant ADR excerpts, acceptance criteria, recent commits list. Subagent returns a diff or commits. Teammate closes the bead task.
4. **Nurture (subagent, mode-aware).** After all `phase-N` implementation tasks are closed (or when a phase is forced to complete early due to a pause/timeout — nurture and secure still run to reconcile state), invoke `/brains:nurture` scoped to phase-N changes, with the skeleton plan in context so the subagent knows what is coming in later phases. Nurture's responsibilities in v0.2.0 (beyond the existing skill scope) include:
    - Ensuring all code changes produced during the phase are committed (atomic commits with conventional-commit messages).
    - Ensuring any generated files that should not be tracked (build artifacts, secrets, local configs, completion markers, `.state/` dirs) are added to `.gitignore`.
    - If the phase ended early (pause/timeout), reflecting the half-complete state in `docs/plans/<topic>-phase-N-nurture.md` and in any user-facing docs affected by the partial work — so a future reader knows what is and isn't done.
    - Standard behavior: reviewing for bugs, missing tests, and spec drift; filing follow-up beads tasks labelled `brains:phase-N+1` or `brains:cleanup` (if no next phase exists).

    Report to `docs/plans/<topic>-phase-N-nurture.md`. Close the `Nurture: phase N` task.
5. **Secure (subagent, mode-aware).** Blocked on nurture completion. Same pattern as nurture. Report to `docs/plans/<topic>-phase-N-secure.md`. Close the `Secure: phase N` task.
6. Write the completion marker file with status and notes.

### Teammate Spawn Modes

Detection order:

1. **Agent teams** — if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set (env or settings.json). Requires Claude Code v2.1.32+.
2. **tmux** — if `tmux` is available on PATH.
3. **Neither** — `/brains:implement` stops with install instructions.

```bash
if [[ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}" == "1" ]]; then
  SPAWN_MODE="agent-teams"
elif command -v tmux >/dev/null 2>&1; then
  SPAWN_MODE="tmux"
else
  SPAWN_MODE="unavailable"
fi
```

| Concern | tmux mode | Agent-teams mode |
|---|---|---|
| Spawn | `tmux split-window "claude '...'"` | `TeamCreate` + teammate spawn with initial prompt |
| Master → teammate messages | Not used; teammate is autonomous after spawn | `SendMessage` for mid-phase course corrections (e.g., unblock a `needs-human` task) |
| Teammate → master signaling | Polling: completion marker file + beads state | `TeammateIdle` auto-notification + beads state |
| Display | Master + one split pane per active teammate | Agent teams' own display mode (`"auto"`: split panes inside tmux, in-process otherwise) |
| `needs-human` recovery | Master updates beads, runs `/brains:implement --resume` (fresh teammate) | Master sends `SendMessage` to resume still-alive teammate; no `--resume` needed |

### Behavioral contract in both spawn modes

- **Task tracker primacy.** Beads is the single source of truth for work items whenever it is available — this rule holds in both tmux mode and agent-teams mode. In agent-teams mode, agent-teams' built-in task list is used only for framework-level coordination signals (spawn state, teammate idle notifications); it MUST NOT hold work items when beads is available. Teammate prompts include an explicit instruction: *"Do not create, claim, or update items in the agent-teams task list. Use beads for all work tracking."* Enforcement is advisory (prompt-level) in v0.2.0; a `TaskCreated` hook that blocks teammate writes to the native list is deferred to v0.3 pending stability of the agent-teams hooks API.
- **Fallback chain.** If beads is unavailable, the agent-teams task list (agent-teams mode) or `TaskCreate`/`TaskUpdate` (tmux mode) becomes the authoritative tracker for that session. The user is told once, at phase-2 start, that they're in a degraded tracking mode.
- **Teammate phase isolation.** Teammate strictly limits itself to tasks labelled with its assigned phase. Cross-phase findings are created with the target phase's label or `cleanup`.
- **Subagent definitions** work in both modes. For v0.2.0, teammates are spawned as generic Claude Code instances with phase-specific prompts; promoting phase roles to reusable subagent definitions (e.g., a `brains-teammate` type) is deferred to v0.3.

### Spawn adapter contract

Both tmux mode and agent-teams mode implement the same four-operation adapter interface. Any future spawn mode (e.g., Docker, remote SSH) must implement these operations to be pluggable.

| Operation | Input | Output | tmux implementation | Agent-teams implementation |
|---|---|---|---|---|
| `spawn(phase_label, initial_prompt)` | phase label, initial prompt | spawn handle (pane id or teammate id) | `tmux split-window "claude '<prompt>'"` | `TeamCreate` + teammate spawn |
| `wait_complete(handle)` | spawn handle | blocks until completion marker or idle signal | poll completion marker file every 15s + poll beads state | await `TeammateIdle` notification + poll beads state |
| `terminate(handle)` | spawn handle | confirmation | `tmux kill-pane -t <pane-id>` | `SendMessage` shutdown request, then cleanup |
| `message(handle, text)` (optional) | spawn handle, message text | delivered / not-supported | not supported — no-op | `SendMessage` |

The `message` operation is optional — tmux mode does not support it, so master logic must not assume it. Any feature that requires mid-flight messaging (e.g., sending a resolved `needs-human` update directly to the running teammate in agent-teams mode) degrades gracefully in tmux mode to the polling-based equivalent.

### Label Conventions

All BRAINS-managed labels are prefixed `brains:` to avoid collision with labels the user may already use in their project. The full label set:

- `brains:topic:<slug>` — applied to every task created by the pipeline. Slug is derived from the topic (kebab-case, lowercase). Enables multiple concurrent BRAINS pipelines in the same repo without state tangling.
- `brains:phase-1`, `brains:phase-2`, ..., `brains:phase-N` — plan-phase membership.
- `brains:ready-for-grooming` — newly created by `/brains:map`; waiting for a teammate to groom.
- `brains:groomed` — grooming complete; task ready for execution.
- `brains:needs-human` — task failed twice or escalated; pending user input. See `needs-human-kind` metadata for variant.
- `brains:cleanup` — a finding with no natural next phase; handled by the final cleanup teammate.
- `brains:superseded` — task from a prior plan that was replaced by a re-architecture run.
- Optional domain labels (e.g., `ui`, `backend`, `auth`) inferred from the ADR — unprefixed, not managed by BRAINS.

### Topic Slugs and Branches

When phase 2 runs, it derives the topic slug from the user's original prompt (e.g., *"add a health-check endpoint"* → `health-check-endpoint`). The slug is used for:
- All `brains:topic:<slug>` task labels
- File names: `docs/plans/YYYY-MM-DD-<slug>-map.md`, etc.
- Optional branch creation

If the user is currently on `main` / `master` / `develop` (or any branch configured as a base branch in `settings.local.json`), phase 2 offers to create a `brains/<slug>` branch before proceeding. If the user declines, phase 2 continues on the current branch. If the user is already on a non-base branch, phase 2 uses the existing branch without prompting.

### Label Lifecycle

```
created by /brains:map:    [brains:topic:<slug>, brains:ready-for-grooming, brains:phase-N, <domain>...]
after grooming:             [brains:topic:<slug>, brains:groomed, brains:phase-N, <domain>...]
after execution:            status=closed  (labels preserved for audit)
```

### Progress Surfacing

Master's pane prints one-line status updates when beads state changes (or when `TeammateIdle` fires in agent-teams mode). No TUI, no dashboard. Example:

```
[brains] phase 2 — teammate active in pane %5
[brains] phase 2 — 4/7 impl closed, 2 in-progress, 1 blocked
[brains] phase 2 — nurture running (blocked on impl)
[brains] phase 2 — secure running
[brains] phase 2 — complete. 3 cleanup tickets filed.
[brains] phase 3 — launching teammate...
```

## Error Handling and Recovery

### Scenarios

| Scenario | Handling |
|---|---|
| Teammate process dies mid-phase | Missing completion marker after idle timeout (default 60min) → master prompts: restart teammate, skip, or abort. |
| Teammate closes pane prematurely | Same as above. |
| Beads becomes unavailable mid-run | Master surfaces error and pauses; writes pause summary to `paused.md`; user resolves and runs `/brains:implement --resume`. |
| Star-chamber provider fails during any phase | Continue with remaining providers; log failed providers in the affected output file. If all providers fail, master pauses and user can retry. |
| User rejects plan at phase-2 gate | Stay in phase 2; revise plan; re-present. |
| Teammate creates tasks labelled for a completed phase | Master detects during polling; relabels to `cleanup` so the final cleanup teammate picks them up. |
| Grooming subagent marks zero tasks as groomed after 3 attempts | Teammate writes `status=failed` to completion marker; master offers retry or abort. |
| tmux becomes unavailable between plan-phases | Master preserves beads state and stops; `/brains:implement --resume` picks up at the next unfinished plan-phase once tmux returns. |
| User doesn't respond to `needs-human` questionnaire within timeout (default 4h) | Master writes `paused.md` and exits. State preserved; user runs `/brains:implement --resume` when ready. |
| Repeated `needs-human` cycles on the same task | Allowed by design. User will rework the task or the acceptance criteria themselves if the loop becomes unproductive. No automatic limit. |
| Completion marker file corrupt or partially written | Master attempts to parse; if parsing fails, treats as a teammate crash (same handling as "teammate process dies"). |
| Beads dependencies create an unresolvable cycle (unlikely — plan generation rejects cycles) | Master aborts phase with a clear error listing the cycle; user fixes the dependency graph manually and re-runs. |

### Task Failure Flow (Phase 3 Execution)

1. **First failure.** Teammate re-engages the star-chamber to re-groom the task. Passes original description, failure output, and subagent reasoning. Star-chamber produces a revised description, revised acceptance criteria, and implementation hints. Task is retried with a fresh subagent.
2. **Second failure (after star-chamber re-groom).** Teammate labels the task `needs-human`. Dependent phase-N tasks stay blocked (beads handles this automatically). Teammate continues with any non-blocked work. If all work is blocked, teammate writes `status=halted-needs-human` to its completion marker and waits without closing its pane.
3. **Master responds.** Master sees `needs-human` during its periodic beads poll and opens a short questionnaire in the master pane. The questionnaire content depends on the sub-kind (see *needs-human variants* below). User answers update the beads task with human-provided guidance and remove `needs-human`.
4. **User non-response timeout.** If the user does not respond to the questionnaire within the configured timeout (default: 4 hours, configurable via `settings.local.json`), master treats the phase as "halt early but tidy up":
    - Before exiting, master runs the current phase's nurture and secure subagents against the partial work (even though not all phase-N tasks are closed). Nurture commits any uncommitted code, updates `.gitignore`, and reflects the half-complete state in the report. Secure runs a security review on whatever was built. Both file follow-up beads tasks as usual.
    - Master then writes `docs/plans/<topic>-paused.md` — same format as the final wrap-up, with a `paused: true` flag in the frontmatter and explicit notes on which tasks were incomplete. `paused.md` and `wrap-up.md` share the same template; the difference is metadata only.
    - Master terminates any halted teammates and exits. Beads state is preserved. The user runs `/brains:implement --resume` when ready; the resumed pipeline picks up from the first phase with open work.
5. **Resume after user response.**
    - *Teammate still alive (typical in agent-teams mode):* dependent tasks unblock automatically. In agent-teams mode, master may also send a `SendMessage` nudge if the teammate is idle. Teammate picks up the unblocked work.
    - *Teammate halted (typical in tmux mode):* master closes the halted teammate's tmux pane (the pane is kept open during `halted-needs-human` state only for diagnostic visibility), then runs `/brains:implement --resume` which launches a fresh teammate that picks up where the halted teammate left off.

Repeated `needs-human` cycles on the same task are allowed by design. If a task bounces back to the human multiple times, that's the user's signal to rework the task themselves or rethink the approach; the system does not impose a loop limit. This two-strike flow replaces the generic three-strike circuit breaker for phase-3 task execution, where human-in-the-loop resolution is cheap. The three-strike rule still applies elsewhere — for example, if the grooming subagent itself fails three times, the teammate halts the phase.

### Needs-human variants

`needs-human` is a single label but covers several distinct situations that produce different questionnaire prompts. The kind is stored as a metadata field on the beads task (`needs-human-kind`):

| Kind | When it's set | Questionnaire prompt to user |
|---|---|---|
| `failure` | Default — task failed twice after star-chamber re-groom | *"Phase N task T-X.Y failed twice. Here is what was tried and what failed: <summary>. How would you like to proceed? You can (a) provide implementation guidance, (b) rewrite the acceptance criteria, (c) mark the task as skipped for this run."* |
| `impossible` | Teammate or star-chamber concludes the task's acceptance criteria cannot be satisfied given the current architecture (e.g., the ADR is wrong, a dependency doesn't exist, a constraint is contradictory) | *"Phase N task T-X.Y appears to be impossible as specified. Here is the reasoning: <summary>. You may know something we don't. Options: (a) provide missing context, (b) adjust the acceptance criteria, (c) mark the task as skipped, (d) escalate to re-architecture."* |
| `re-architecture` | Teammate discovers that an accepted ADR's assumptions are invalid (a library doesn't behave as expected, a constraint was missed, a dependency is deprecated). Filed explicitly with `needs-human-kind=re-architecture` | *"Phase N task T-X.Y surfaces an architecture problem: <summary>. Options: (a) suggest an in-place workaround that avoids re-architecture, (b) stop and run `/brains:brains` again with this context — existing phase-2 task stubs will be cleaned up and regenerated against the new ADR."* |

Because the phase's nurture and secure tasks are blocked by the in-progress implementation tasks, a re-architecture escalation naturally pauses the phase without any special cleanup logic — it's the same halt behavior as the default failure kind.

### Task Failure State Machine

```
                            ┌───────────────┐
                            │   groomed     │
                            │ (ready to     │
                            │  execute)     │
                            └───────┬───────┘
                                    │ execute
                                    ▼
                            ┌───────────────┐
                            │  in-progress  │
                            └───┬───────┬───┘
                    success     │       │     failure 1
                                ▼       ▼
                          ┌─────────┐  ┌──────────────┐
                          │  closed │  │  regrooming  │
                          │(terminal│  │ (star-chamber│
                          │   OK)   │  │   re-groom)  │
                          └─────────┘  └──────┬───────┘
                                              │ retry
                                              ▼
                                       ┌───────────────┐
                                       │  in-progress  │
                                       └───┬───────┬───┘
                              success      │       │      failure 2
                                           ▼       ▼
                                     ┌─────────┐  ┌──────────────┐
                                     │  closed │  │ needs-human  │
                                     └─────────┘  │  (kind: one  │
                                                  │  of 3 above) │
                                                  └──────┬───────┘
                                                         │ user responds
                                      ┌──────────────────┼──────────────────┐
                                      ▼                  ▼                  ▼
                              ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
                              │ retry-with-  │   │   skipped    │   │re-architect. │
                              │  guidance    │   │ (terminal OK │   │  pause phase,│
                              │(→ in-progress│   │ — not built) │   │  run phase 1 │
                              └──────────────┘   └──────────────┘   └──────────────┘

User non-response timeout (4h default) from needs-human:
  → master writes paused.md, exits
  → beads state preserved
  → /brains:implement --resume picks up
```

Terminal states: `closed` (done), `skipped` (deliberately not built — noted in the final wrap-up), `re-architected` (phase 1 restarted; old tasks cleaned up by the new phase-2 run).

### Resumability

- **Phase 1** is not resumable. The questionnaire is interactive; interruption means restarting. Initial research on disk is reused if present and recent (<24h).
- **Phase 2** is trivially re-runnable before any grooming has started. After grooming, re-running requires `--force` because beads state conflicts.
- **Phase 3** is resumable at plan-phase granularity. `/brains:implement --resume` queries beads, finds the first plan-phase with open tasks, and launches a teammate there. Same launch flow as a fresh run.

## Cross-Cutting Concerns

### Phase Contracts

Each phase has a precise input and output contract. Phase boundaries are enforced by file presence and user gates — if a consuming phase can't find its inputs, it errors with actionable guidance rather than silently re-doing work.

| Phase | Consumes | Produces | Gate |
|---|---|---|---|
| `brains` | User prompt; optional existing ADRs in `docs/adr/` | Accepted ADR(s) in `docs/adr/`; research notes in `docs/plans/*-research.md`; architecture version pins (SHOULD) embedded in ADR | User accepts ADR |
| `map` | Accepted ADRs; research notes; codebase (re-explored only if stale or commits landed since) | Topic slug; plan document in `docs/plans/*-map.md` (overwritable); beads tasks labelled with `brains:topic:<slug>`, `brains:ready-for-grooming`, `brains:phase-N`, plus umbrella nurture/secure/cleanup tasks; optional branch `brains/<slug>` | User accepts plan |
| `implement` | Plan document (including persisted `Mode:`); ADRs; beads task state (filtered by `brains:topic:<slug>`) | Per-phase nurture/secure reports; `wrap-up.md` (or `paused.md` if interrupted); all pipeline beads tasks in a terminal state | Implicit — pipeline ends or pauses |

Any phase that runs standalone (not via the chain) applies the same contract: if it can't find its consumed inputs, it stops and tells the user to run the prerequisite phase, or supplies the inputs via arguments.

### Mode Semantics Summary

| Mode | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|
| `--single` | No star-chamber; subagent does everything | Plan generated locally, no review | Nurture/secure run without star-chamber review |
| `--parallel` (default) | Star-chamber generates/reviews questions and architecture | Star-chamber reviews plan | Nurture/secure send findings to star-chamber for second opinion |
| `--debate` | Star-chamber debates questions and architecture across rounds | Star-chamber debates the plan | Nurture/secure run as star-chamber debates |

Mode inheritance across chained invocations is strict: phase 1's mode becomes phases 2 and 3's default. At each gate, the user may override with a flag.

### Shared Reference Documents

Three new references live at the top of the plugin so skill files stay focused on user-facing flow:

- **`references/teammate-protocol.md`** — initial prompt template for teammates, completion marker format (JSON: `{status, phase, finished_at, notes}`), master polling protocol and intervals, `--resume` semantics, spawn-mode detection code.
- **`references/beads-integration.md`** — auto-init command (`bd init --local`), label lifecycle, `/brains:map` task creation pattern, teammate query/update/close patterns, `TaskCreate`/`TaskUpdate` fallback.
- **`references/failure-recovery.md`** — first-failure star-chamber re-groom, second-failure `needs-human` labeling, master questionnaire format, auto-resume semantics.

`references/multi-llm-protocol.md` (already present) is unchanged — it remains the single source of truth for star-chamber invocation mechanics.

## Migration Artifacts

### Files Deleted

```
skills/storm/SKILL.md
skills/research/SKILL.md
skills/architect/SKILL.md
```

### Files Created

```
skills/brains/SKILL.md                        (major rewrite — phase 1 entry)
skills/brains/references/visual-companion.md  (moved from skills/storm/references/)
skills/brains/scripts/                        (moved from skills/storm/scripts/ — visual companion server)
skills/map/SKILL.md                           (new — phase 2)
skills/map/references/plan-format.md          (new — plan document template)
references/teammate-protocol.md               (new)
references/beads-integration.md               (new)
references/failure-recovery.md                (new)
```

### Files Rewritten

```
skills/implement/SKILL.md                     (total rewrite — phase 3 teammate orchestrator)
skills/suggest/SKILL.md                       (describe the three-phase flow)
README.md                                     (skills table, pipeline diagram, phase output table)
docs/testing-humans.md                        (rewrite walkthrough for three-phase flow)
docs/testing-llm.md                           (rewrite assertions for new flow)
```

### Files Kept with Minor Edits

```
skills/nurture/SKILL.md                       (must support subagent invocation, must scope to phase label, must assign findings to next phase or "cleanup")
skills/secure/SKILL.md                        (same edits as nurture)
skills/setup/SKILL.md                         (add beads init default, teammate-protocol dependency, tmux + agent-teams detection)
skills/setup/references/settings-format.md    (add beads-init default, spawn-mode detection docs)
references/multi-llm-protocol.md              (no structural change)
.claude-plugin/plugin.json                    (bump version to 0.2.0)
```

### Deferred to v0.3

```
assets/brains-lifecycle.jpeg                  (redraw for three phases)
skills/*/agents/brains-teammate.md            (reusable teammate subagent definition)
agent-teams TaskCreated hook enforcement      (block teammate writes to native task list)
reduced teammate permission scope             (teammates currently inherit lead's permission mode; in some cases a reduced scope would be safer, but scoping is deferred to v0.3 pending agent-teams API maturity)
```

### Minimum versions (to be pinned at release)

| Dependency | Floor policy |
|---|---|
| Claude Code | Version installed on the developer's machine at v0.2.0 release time. Agent-teams features require v2.1.32+ per upstream docs, but base pipeline (tmux mode) may work on earlier versions — pin the floor once at release. |
| beads | Same policy — pin to the version installed at release. Setup skill validates the floor. |
| tmux | Any version that supports `split-window -h` and `kill-pane -t`. No explicit floor — practically any tmux from the last decade. |
| uv | Any version that ships `uvx` (0.1+). |

Setup skill checks each at install time and emits an install hint if the floor isn't met.

## Testing Strategy

### Test Layers

| Layer | What it covers | How |
|---|---|---|
| Skill file logic | Mode parsing, argument handling, prerequisite checks, file-path generation | Manual dry runs with stubbed tool responses during development |
| Reference-doc consistency | `teammate-protocol.md`, `beads-integration.md`, `failure-recovery.md` stay consistent with skills referencing them | Manual review + grep audits |
| Human walkthroughs | Full end-to-end flow from a fresh project with a realistic small topic; covers all three phases, both spawn modes, and at least one failure injection | `docs/testing-humans.md` rewrite |
| LLM structured tests | Automated pass/fail checks an LLM tester can run against a sandbox repo | `docs/testing-llm.md` rewrite |

### Key Test Scenarios

1. Happy path, tmux mode.
2. Happy path, agent-teams mode — verify equivalence with scenario 1.
3. ADR rejection at phase-1 gate — verify questions regenerate with rejection context; research reused.
4. Plan rejection at phase-2 gate — verify revise-and-re-present loop stays within phase 2.
5. Task fails once → re-groom → succeeds — verify star-chamber re-groom triggers.
6. Task fails twice → `needs-human` → user resolves → auto-resume fires.
7. Beads auto-init — fresh repo, verify one-line announcement and correct initialization.
8. Missing tmux and missing agent-teams flag — verify phase 3 stops with clear install instructions.
9. Star-chamber provider failure mid-phase — verify pipeline continues with remaining providers and failed-provider note appears in output.

### What We Explicitly Do Not Test in v0.2

- Star-chamber output quality (provider-dependent; untestable deterministically).
- Nurture/secure finding accuracy (semantic judgment).
- Visual companion browser rendering (human-verified in walkthroughs; no automated UI tests).

## Open Questions

None blocking. Implementation-time details, all configurable via `settings.local.json`:

- Completion marker file path — `docs/plans/.state/` for auditability; must be `.gitignore`d.
- Teammate idle timeout (default 60 min).
- User-response timeout for `needs-human` questionnaires (default 4 hours).
- Master progress-polling interval (default 15s).
- Codebase-exploration staleness threshold for phase 2 (default: research doc older than 1 hour, or any commits since).
- Base branch names that trigger the topic-branch offer in phase 2 (default: `main`, `master`, `develop`).

## Acceptance Criteria for v0.2.0 Release

- All three new/rewritten phase skills work end-to-end on the sample topic from `docs/testing-humans.md`.
- All scenarios in the test plan pass manual review.
- Nurture and secure skills work both standalone and subagent-invoked.
- `README.md` accurately describes the new three-phase model.
- `plugin.json` is at version `0.2.0`.
- No references to `/brains:storm`, `/brains:research`, or `/brains:architect` remain in any markdown file in the repo.
