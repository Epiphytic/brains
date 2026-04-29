# Plan Document Format

The canonical plan document structure produced by `/brains:map`. The plan document is the tracker — it is overwritten every time phase 2 runs. ADRs, research notes, and per-phase reports are archival by contrast and must not be overwritten.

## Template

```markdown
# Plan: <topic>

**Slug:** <topic-slug>
**ADRs:** <list of paths, comma-separated>
**Research:** <research doc path>
**Mode:** <--single | --parallel | --debate>   <!-- persisted for --resume -->
**Autopilot:** <true | false>   <!-- persisted for --resume -->
**Accept-ADRs:** <true | false> <!-- persisted for --resume; ADR-005 req 35 -->
**Lean:** <true | false>        <!-- persisted for --resume -->
**Bullets:** <true | false>     <!-- persisted for --resume; serial-sweep mode -->
**Skills:** <true | false>      <!-- persisted for --resume; ADR-005 req 21-22 -->
**Teammate-model:** <sonnet | opus | haiku> <!-- resolved by /brains:implement on first run -->
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

## Header Fields

| Field | Purpose | Read by |
|---|---|---|
| Slug | Topic identifier used in task labels (brains:topic:<slug>) | /brains:map, /brains:implement, all teammates |
| ADRs | Immutable source of architectural truth | All phases |
| Research | Snapshot of codebase/ecosystem understanding | /brains:map (for re-exploration decision), teammates (grooming input) |
| Mode | Default mode for /brains:implement --resume | /brains:implement |
| Autopilot | Persisted autopilot state for --resume (CLI override wins) | /brains:implement |
| Accept-ADRs | Persisted ADR auto-accept state for --resume (CLI override wins) | /brains:implement |
| Lean | Persisted lean-mode state for --resume (CLI override wins) | /brains:implement |
| Bullets | Whether the plan was emitted in serial-sweep shape (inline execution, no teammate spawn) | /brains:map (gate behavior), /brains:implement --resume |
| Skills | Persisted --skills state for --resume (CLI override wins) | /brains:implement, teammate (forwarded as raw text in initial prompt) |
| Teammate-model | Per-phase teammate Claude Code model tier (resolved on first run; persisted for --resume) | /brains:implement |
| Branch | Branch the tasks were created on | /brains:implement (sanity check) |

## Task ID Format

`T-<phase>.<index>` — e.g., `T-3.2` is the second task in plan-phase 3. Indexes start at 1.

## Acceptance Criteria

Each task acceptance criterion MUST be a single line, verifiable by reading either a file, a command output, or a test result. Avoid vague criteria like "works well" or "is clean."

Good: *"docs/plans/<slug>-phase-2-nurture.md exists and contains a section titled 'Issues Fixed'."*

Bad: *"nurture phase is complete."*

## Plan-Phase Boundaries

Each plan-phase is independently testable — the end of plan-phase N produces a working, verifiable state. This is critical because the teammate for phase N runs nurture and secure at the end of its work; if plan-phase N's output isn't testable, nurture can't do its job.

## Serial Sweep Mode (bullets)

An alternative output shape for plans that meet a strict eligibility heuristic. When active, the plan is a single sweep of coarse tasks executed inline by the orchestrator — no teammate spawn, no per-phase handoff. Per ADR-005 reqs 44–49.

### Trigger conditions

Auto-detected when ALL three hold (per ADR-005 req 45):

1. The ADR introduces no new external dependencies or services.
2. All work is topologically serial — no parallel-independent streams.
3. No `risk:high` markers AND no architectural unknowns surfaced by grooming.

Explicit `--bullets` forces serial-sweep regardless of auto-detection. `--no-bullets` forces standard multi-phase shape regardless. The standard multi-phase template (above) remains the default for any plan that fails the eligibility check.

### Plan shape

- **Plan-phases:** 1 (or at most 2 with a clear setup/teardown split).
- **Tasks per plan-phase:** 3–6 coarse beads tasks.
- **Task body:** each task carries a markdown bullet checklist of constituent file-level steps (the granularity normally absorbed into per-phase grooming) so the inline executor has an unambiguous to-do list.
- **Plan header:** the `Bullets: true` field MUST be present so `/brains:implement --resume` honors the inline-execution choice.

### User gate behavior

The user gate (step 7 of `/brains:map`) defaults to **"Accept and skip teammate spawn"** — implementation runs inline in the current orchestrator session. Under `--autopilot --bullets`, the gate is skipped entirely and the orchestrator proceeds to inline execution directly. If grooming subsequently surfaces `risk:high` or new architectural unknowns, the skill MUST escalate back to the standard multi-phase shape with a one-line warning to the user (per ADR-005 req 47).

### Example (3-task serial sweep)

```markdown
# Plan: <topic>

**Slug:** <topic-slug>
**ADRs:** docs/adr/2026-04-28-005-foo.md
**Research:** docs/research/2026-04-28-foo-research.md
**Mode:** --parallel
**Bullets:** true
**Branch:** brains/<slug>

## Phase 1: Implementation

- [ ] **T-1**: Add flag parsing
  - Depends on: none
  - Acceptance: `skill.md` argument-hint contains `--foo`; flag resolves via 4-layer chain.
  - Steps:
    - Update `skills/foo/SKILL.md` argument-hint frontmatter
    - Add 4-layer resolution block alongside existing flag block
    - Document defaults in `references/foo-flag.md`
- [ ] **T-2**: Implement core behavior
  - Depends on: T-1
  - Acceptance: feature triggers when flag is true; existing tests pass.
  - Steps:
    - Wire flag into the core function in `src/foo.py`
    - Add structured-log line on activation
    - Add unit test in `tests/test_foo.py`
- [ ] **T-3**: Update docs and changelog
  - Depends on: T-2
  - Acceptance: README mentions the flag; CHANGELOG has an entry under the next version.
  - Steps:
    - Add `--foo` to the README usage section
    - Add CHANGELOG entry under `[Unreleased]`
```

The canonical reference plan that exercises this shape is `/home/liamhelmer/repos/epiphytic/brains/docs/plans/2026-04-28-brains-skills-integration-map.md`.
