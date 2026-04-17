---
name: map
description: This skill should be used when the user asks to "map out the plan", "create the implementation plan", "outline the tasks", "plan it out", "sketch the implementation", or invokes "/brains:map". Phase 2 of the BRAINS pipeline: high-level plan generation (no implementation specifics), topic-slug derivation, optional branch creation, beads task creation with brains:-prefixed labels, and user approval gate. Supports --single, --parallel (default), and --debate modes for plan review, plus an optional --autopilot flag that skips user gates and auto-chains into /brains:implement --autopilot. Chains into /brains:implement at the user gate.
user-invocable: true
argument-hint: "[--single|--parallel|--debate] [--autopilot] [--rounds N] [topic]"
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent, TaskCreate, TaskUpdate
---

# BRAINS Phase 2: Map High-Level Plan

Generate a stub-level task plan from accepted ADR(s), create beads tasks with brains: labels, and chain into `/brains:implement`. Default mode: `--parallel`.

Set the plugin base path:

```bash
BRAINS_PATH="<base directory from header>/../.."
```

## Mode Behavior

| Mode | Plan review |
|---|---|
| `--single` | Local subagent only |
| `--parallel` (default) | Star-chamber reviews task ordering, sizing, coverage, phasing |
| `--debate` | Star-chamber debates the plan across rounds |

For `--parallel` and `--debate`, follow `$BRAINS_PATH/references/multi-llm-protocol.md`.

## Autopilot (`--autopilot`)

Orthogonal flag that composes with any mode. When set:

- **Skip all user prompts** — no branch prompt (step 3), no plan-acceptance gate (step 7).
- **Star-chamber still runs per mode** (`--parallel` reviews, `--debate` debates); feedback is **auto-integrated into the plan** without a user confirmation step. Think of this as "fix anything that needs fixing" — actionable findings get applied; items requiring a true architectural judgment call should be surfaced by escalating that plan-phase's tasks to `brains:needs-human` during phase 3 rather than blocking here.
- **Branch offer becomes automatic:** on a base branch, create `brains/<slug>` without asking; otherwise stay on the current branch (same as non-autopilot behavior).
- **Chain into `/brains:implement --autopilot`** with inherited mode at the phase transition — do not prompt.

Autopilot is propagated downstream — the inherited state is persisted in the plan header (see step 11) and honored by `/brains:implement --resume`.

## Process

### 1. Parse arguments

Parse mode, `--autopilot`, rounds, and topic. If no topic and no prior phase 1 output exists, ask the user. If chained from phase 1, inherit both the mode and autopilot state.

In autopilot, if a topic is truly missing and no prior phase 1 output exists, do NOT stall waiting for input — stop with a `brains:needs-human` style message to the user explaining that `/brains:map --autopilot` requires either a topic argument or a prior phase 1 output.

### 2. Derive topic slug

Convert the topic to kebab-case lowercase. Example: *"add a health-check endpoint"* → `health-check-endpoint`.

### 3. Branch offer

Determine the current branch:

```bash
CURRENT_BRANCH=$(git branch --show-current)
```

Base branches (configurable via `settings.local.json` key `brains.baseBranches`, default `main`, `master`, `develop`):

- If `CURRENT_BRANCH` is a base branch:
  - **Interactive:** prompt *"Create topic branch `brains/<slug>` and switch to it? [y/n]"* — on yes, `git checkout -b brains/<slug>`; on no, continue on current branch with a one-line warning that BRAINS tasks will be labelled with the current branch name.
  - **Autopilot:** skip the prompt and auto-create `brains/<slug>` (`git checkout -b brains/<slug>`). Emit a one-line status update instead.
- Otherwise: use the current branch without prompting (same in both modes).

### 4. Load inputs

Find accepted ADR(s) in `docs/adr/` matching the topic (by filename pattern or by user-selection if ambiguous) and the research document at `docs/plans/<slug>-research.md`.

Codebase exploration policy:
- If the research document's mtime is within 1 hour AND no git commits landed on the current branch since then: reuse phase 1's exploration; skip this step.
- Otherwise: spawn a refresher subagent (Agent with `feature-dev:code-explorer`) scoped to re-explore files listed in the ADR; note drift. Surface significant drift to the user before proceeding; append minor drift to the plan document.

### 5. High-level plan generation (subagent)

Spawn a planning subagent with a prompt that emphasizes:
- Produce stub-level tasks (no implementation specifics — intentionally stub-level so re-architecture in phase 3 is cheap to clean up)
- Identify inter-task dependencies
- Group into phases if >12 tasks (target: each phase independently testable)
- Include acceptance criteria per task

Output path: `docs/plans/YYYY-MM-DD-<slug>-map.md`. This file IS overwritten on every phase-2 run. Do not preserve prior map documents — the plan is the tracker, not the archive. ADRs and research documents remain immutable.

### 6. Plan review (mode-dependent)

Behavior depends on the selected mode:

- **`--single`:** Skip plan review entirely. The subagent's output is accepted as-is and passed directly to the user gate.
- **`--parallel` (default):** Invoke the star-chamber to review the plan in parallel. Reviewers focus on task ordering, sizing, coverage, and phasing; their feedback is integrated into a revised plan before presenting to the user. Follow the parallel protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`.
- **`--debate`:** Invoke the star-chamber to debate the plan across rounds. Reviewers challenge each other's positions on ordering, sizing, coverage, and phasing until consensus or the round limit is reached; the synthesized outcome is integrated into the plan. Follow the debate protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`.

In `--autopilot`, star-chamber feedback (when applicable) is integrated without a user confirmation step — apply actionable findings, and surface anything that looks like a genuine architectural re-think as a `brains:needs-human` task during phase 3 rather than blocking here.

### 7. User gate

- **Interactive:** Present the plan. Options:
  - **Reject:** revise in place, re-present. Stay within phase 2.
  - **Accept:** proceed to task creation.
- **Autopilot:** skip the gate. Proceed directly to task creation. Emit a one-line status update summarizing the plan (phase count, task count, any star-chamber findings that were integrated).

### 8. Task tracker selection

Follow `$BRAINS_PATH/references/beads-integration.md` § Tracker Selection.

### 9. Task creation

Follow `$BRAINS_PATH/references/beads-integration.md` § Task Creation (phase 2). For each plan-phase, create implementation tasks, the Nurture umbrella task, and the Secure umbrella task. For the final plan-phase, also create the Cleanup task.

### 10. Re-architecture cleanup

If this phase-2 run was triggered by a `needs-human-kind=re-architecture` escalation from phase 3, follow `$BRAINS_PATH/references/beads-integration.md` § Re-Architecture Cleanup BEFORE step 9.

Detection: the caller sets the environment variable `BRAINS_REARCHITECTURE=1`; `/brains:map` reads it on entry.

### 11. Write plan header with persisted mode

Update the map document to include the following frontmatter/header fields:

```markdown
# Plan: <topic>

**Slug:** <slug>
**ADRs:** <list of paths>
**Research:** <research doc path>
**Mode:** <--single | --parallel | --debate>
**Autopilot:** <true | false>
**Branch:** <branch name>
```

The `Mode:` and `Autopilot:` lines are read by `/brains:implement --resume`. CLI flags on `--resume` override the persisted values (e.g., `/brains:implement --resume --single` or `/brains:implement --resume --autopilot`).

## Phase Transition

After tasks are created, chain into phase 3:

- **Interactive:** > "Phase 2 complete. Plan at `<map path>`. <N> tasks created across <K> plan-phase(s). Chaining into `/brains:implement` with mode `<mode>`."
  Invoke `/brains:implement` directly.
- **Autopilot:** > "Phase 2 complete. Plan at `<map path>`. <N> tasks created across <K> plan-phase(s). Chaining into `/brains:implement --autopilot` with mode `<mode>`."
  Invoke `/brains:implement --autopilot` directly — phase 3 will not prompt the user unless a `brains:needs-human` task surfaces.

## Additional Resources

- **`$BRAINS_PATH/references/multi-llm-protocol.md`** — shared multi-LLM invocation protocol
- **`$BRAINS_PATH/references/beads-integration.md`** — task tracker selection, label conventions, task creation commands
- **`$BRAINS_PATH/skills/map/references/plan-format.md`** — plan document template (created next in task 2.3)
