---
name: map
description: This skill should be used when the user asks to "map out the plan", "create the implementation plan", "outline the tasks", "plan it out", "sketch the implementation", or invokes "/brains:map". Phase 2 of the BRAINS pipeline: high-level plan generation (no implementation specifics), topic-slug derivation, optional branch creation, beads task creation with brains:-prefixed labels, and user approval gate. Supports --single, --parallel (default), and --debate modes for plan review, plus an optional --autopilot flag that skips user gates and auto-chains into /brains:implement --autopilot. Chains into /brains:implement at the user gate.
user-invocable: true
argument-hint: "[--single|--parallel|--debate] [--autopilot] [--lean] [--skills|--no-skills] [--bullets|--no-bullets] [--rounds N] [topic]"
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

For `--parallel` and `--debate`, follow `$BRAINS_PATH/references/multi-llm-protocol.md`. Under `--lean`, follow the compact excerpt at `$BRAINS_PATH/references/multi-llm-protocol-compact.md`; consult the full file only for debate-round synthesis or error handling.

## Autopilot (`--autopilot`)

Orthogonal flag that composes with any mode. When set:

- **Skip all user prompts** — no branch prompt (step 3), no plan-acceptance gate (step 7).
- **Star-chamber still runs per mode** (`--parallel` reviews, `--debate` debates); feedback is **auto-integrated into the plan** without a user confirmation step. Think of this as "fix anything that needs fixing" — actionable findings get applied; items requiring a true architectural judgment call should be surfaced by escalating that plan-phase's tasks to `brains:needs-human` during phase 3 rather than blocking here.
- **Branch offer becomes automatic:** on a base branch, create `brains/<slug>` without asking; otherwise stay on the current branch (same as non-autopilot behavior).
- **Chain into `/brains:implement --autopilot`** with inherited mode at the phase transition — do not prompt.

Autopilot is propagated downstream — the inherited state is persisted in the plan header (see step 11) and honored by `/brains:implement --resume`.

## Process

### 1. Parse arguments

Parse mode, `--autopilot`, `--lean`, `--skills` / `--no-skills`, `--bullets` / `--no-bullets`, rounds, and topic. If no topic and no prior phase 1 output exists, ask the user. If chained from phase 1, inherit the mode, autopilot state, `--lean` state, and `--skills` state.

`--grill` MUST be rejected with a clear error and a non-zero exit. Print: *"--grill is phase-1 only; use /brains:brains --grill instead"* and stop. `--grill` does not propagate from phase 1 either (per ADR-005 req 23).

**Flag resolution for `--skills`** (per ADR-005 reqs 18-19): 4-layer precedence, top-to-bottom — first definitive value wins:

1. **Explicit CLI flag** — `--skills` / `--no-skills` on the command line wins.
2. **`.claude/brains.local.md` Flags table** — `skills` row with `true` or `false`.
3. **`~/.config/brains/defaults.json` `flags.skills`** — boolean.
4. **Built-in default** — `false`.

When the resolved value is `true`, this skill follows `$BRAINS_PATH/references/skills-detection.md` and `$BRAINS_PATH/references/skills-invocation.md`. The vendored `$BRAINS_PATH/references/find-skills.md` is read only when the find-skills fallback fires.

**Flag resolution for `--bullets`** (per ADR-005 reqs 44, 49): same 4-layer precedence, top-to-bottom — first definitive value wins:

1. **Explicit CLI flag** — `--bullets` / `--no-bullets` on the command line wins.
2. **`.claude/brains.local.md` Flags table** — `bullets` row with `true` or `false`.
3. **`~/.config/brains/defaults.json` `flags.bullets`** — boolean.
4. **Built-in default** — `false` (auto-detection in step 5 may still flip the resolved value to `true` when the standard heuristic holds; `--no-bullets` always wins and forces standard shape).

In autopilot, if a topic is truly missing and no prior phase 1 output exists, do NOT stall waiting for input — stop with a `brains:needs-human` style message to the user explaining that `/brains:map --autopilot` requires either a topic argument or a prior phase 1 output.

`--lean` activates the token-efficiency path: use the compact multi-llm-protocol excerpt inline rather than reading the full reference; read the `Research-Summary` block from the plan header (written by phase 1) instead of re-reading the full research document — drill down to the full file only when a summary field is empty-but-relevant; follow the role manifest at `$BRAINS_PATH/manifests/phase-2-map.md`. Default off. `--lean` propagates to `/brains:implement` at the phase transition.

### 2. Derive topic slug

Convert the topic to kebab-case lowercase. Example: *"add a health-check endpoint"* → `health-check-endpoint`.

### 3. Branch offer

**Note:** When chained from `/brains:brains` (the common case), step 9 of phase 1 has already moved the user to a topic branch — this step is a no-op fallback for standalone `/brains:map` invocations on a base branch (per ADR-005 req 38).

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

Find accepted ADR(s) in `docs/adr/` matching the topic (by filename pattern or by user-selection if ambiguous) — ADRs are ALWAYS loaded whole, under all modes including `--lean`.

**Research document loading depends on `--lean`:**
- **Non-lean (default):** read the full research document at `docs/research/<slug>-research.md` (legacy fallback: `docs/plans/<slug>-research.md` for pre-v0.5 ADR runs). Preserves v0.2.x reading behavior.
- **Under `--lean`:** read only the `research-summary` block stashed by phase 1 (per `$BRAINS_PATH/skills/brains/references/research-summary-schema.md`). Drill down into the full research document only when a summary field is empty-but-relevant, when a task is flagged `risk:high` during grooming, or when `--ignore-research-summary` was passed.

Codebase exploration policy:
- If the research document's mtime is within 1 hour AND no git commits landed on the current branch since then: reuse phase 1's exploration; skip this step.
- Otherwise: spawn a refresher subagent (Agent with `feature-dev:code-explorer`) scoped to re-explore files listed in the ADR; note drift. Surface significant drift to the user before proceeding; append minor drift to the plan document.

### 5. High-level plan generation (subagent)

Spawn a planning subagent with a prompt that emphasizes:
- Produce stub-level tasks (no implementation specifics — intentionally stub-level so re-architecture in phase 3 is cheap to clean up)
- Identify inter-task dependencies
- Group into phases if >12 tasks (target: each phase independently testable)
- Include acceptance criteria per task

#### 5a. Serial-sweep eligibility (per ADR-005 reqs 44-47)

Before (or alongside) plan generation, evaluate the three-condition heuristic:

- **(a)** The ADR introduces no new external dependencies or services.
- **(b)** All work is topologically serial — no parallel-independent streams.
- **(c)** No `risk:high` markers AND no architectural unknowns surfaced by grooming.

Pass these conditions into the planning subagent's prompt and ask it to return a verdict line `bullets-eligible: true | false` alongside the plan. Resolve the effective bullets state:

- If `--no-bullets` is the resolved CLI/config value, force standard multi-phase shape regardless of the verdict.
- Else if `--bullets` is the resolved CLI/config value OR the verdict is `bullets-eligible: true`, set the effective state to **bullets** and instruct the subagent to emit the plan in **serial-sweep shape**: 1 plan-phase (or at most 2 with a clear setup/teardown split), 3–6 coarse beads tasks, each with a markdown bullet checklist body of constituent file-level steps. See `$BRAINS_PATH/skills/map/references/plan-format.md` § "Serial Sweep Mode (bullets)".
- Otherwise, use the standard multi-phase shape (existing behavior).

If grooming downstream surfaces `risk:high` or new architectural unknowns, the skill MUST escalate back to standard multi-phase shape with a one-line warning to the user (per ADR-005 req 47).

Output path: `docs/plans/YYYY-MM-DD-<slug>-map.md`. This file IS overwritten on every phase-2 run. Do not preserve prior map documents — the plan is the tracker, not the archive. ADRs and research documents remain immutable.

### 6. Plan review (mode-dependent)

Behavior depends on the selected mode:

- **`--single`:** Skip plan review entirely. The subagent's output is accepted as-is and passed directly to the user gate.
- **`--parallel` (default):** Invoke the star-chamber to review the plan in parallel. Reviewers focus on task ordering, sizing, coverage, and phasing; their feedback is integrated into a revised plan before presenting to the user. Follow the parallel protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`.
- **`--debate`:** Invoke the star-chamber to debate the plan across rounds. Reviewers challenge each other's positions on ordering, sizing, coverage, and phasing until consensus or the round limit is reached; the synthesized outcome is integrated into the plan. Follow the debate protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`.

In `--autopilot`, star-chamber feedback (when applicable) is integrated without a user confirmation step — apply actionable findings, and surface anything that looks like a genuine architectural re-think as a `brains:needs-human` task during phase 3 rather than blocking here.

### 7. User gate

#### 7a. Commit + push plan, surface link (per ADR-005 req 37c)

BEFORE presenting the gate options or showing the plan summary (interactive), AND in autopilot before the inline status update, the skill MUST commit + push the plan document so the user can review it on GitHub. This also applies to out-of-band plan-review requests where the user interrupts autopilot mid-flight to revise the plan.

```bash
PLAN_PATH="docs/plans/YYYY-MM-DD-<slug>-map.md"
CURRENT_BRANCH=$(git branch --show-current)

# Commit only when there are unstaged or staged changes to the plan file
if ! git diff --quiet -- "$PLAN_PATH" || ! git diff --cached --quiet -- "$PLAN_PATH"; then
  git add "$PLAN_PATH"
  git commit -m "docs(plan): map <slug>"
fi

# Push — set upstream if the branch has none
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git push
else
  git push -u origin "$CURRENT_BRANCH"
fi
```

After a successful push, IF `git remote get-url origin` contains the substring `github.com`, surface a clickable GitHub link (same derivation pattern as `skills/brains/SKILL.md` step 9 sub-step (d) — handle both `https://` and `git@github.com:` remote forms; strip trailing `.git`):

```
Plan doc:
- https://<host>/<owner>/<repo>/blob/<branch>/<plan-path>
```

Skip the link block silently when no GitHub remote exists. Push failures should be surfaced to the user (do NOT bypass hooks or force-push); offer retry / skip-push-and-continue / abort, mirroring the phase-1 commit+push handling.

#### 7b. Present gate options

- **Interactive:** Present the plan. Options:
  - **Reject:** revise in place, re-present. Stay within phase 2.
  - **Accept:** proceed to task creation, then chain to `/brains:implement`.
  - **(Conditional) Accept and skip teammate spawn** — available ONLY when all three are true: plan has <10 total tasks; all tasks fit in a single plan-phase; no task is flagged `risk:high` during grooming (check the per-task grooming annotations, or run a lightweight grooming pass now if not yet performed). When accepted, create the beads tasks (step 9) and then proceed to inline implementation in the CURRENT session without invoking `/brains:implement`. Execute tasks directly; run `/brains:nurture --scope phase-1` and `/brains:secure --scope phase-1` at the end.
- **Autopilot:** skip the gate. Proceed directly to task creation and chain to `/brains:implement --autopilot`. Autopilot NEVER auto-selects the skip-teammate-spawn option — it continues to chain through the full pipeline. Emit a one-line status update summarizing the plan (phase count, task count, any star-chamber findings that were integrated).

**Bullets-mode override (per ADR-005 req 47):** when the effective state from step 5a is bullets, the gate behavior changes:

- **Interactive `--bullets`:** still present the gate, but pre-select "Accept and skip teammate spawn" as the recommended option (option 3 / inline) and label it as such. The eligibility constraints in the third bullet above (<10 tasks, single plan-phase, no `risk:high`) are satisfied by construction in serial-sweep mode, so the conditional option is always available.
- **`--autopilot --bullets`:** skip the gate prompt entirely (autopilot already gates prompts) and proceed directly to the inline-execution path in the current orchestrator session — do NOT spawn a teammate, do NOT chain `/brains:implement --autopilot`. After task creation, execute the plan inline and run `/brains:nurture --scope phase-1` and `/brains:secure --scope phase-1` at the end.
- If grooming subsequently surfaces `risk:high` or new architectural unknowns, escalate back to standard multi-phase shape with a one-line warning and resume the standard gate/teammate-spawn behavior.

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
**Accept-ADRs:** <true | false>
**Lean:** <true | false>
**Bullets:** <true | false>
**Skills:** <true | false>
**Teammate-model:** <sonnet | opus | haiku | (unset — /brains:implement will resolve and write back)>
**Branch:** <branch name>

<!-- Under --lean, embed the research-summary block inline here. Fields per
     skills/brains/references/research-summary-schema.md. Example:

```yaml
research-summary:
  libraries-and-versions: |
    - FastAPI 0.112
    - SQLAlchemy 2.0
  deprecated-apis-to-avoid: |
    - SQLAlchemy 1.x Query API
  codebase-patterns: |
    - Repository pattern in src/repos/
  prior-art: |
    - ADR-003 (auth middleware refactor)
  constraints: |
    - MUST maintain Python 3.11 compatibility
```
-->
```

The `Mode:`, `Autopilot:`, `Accept-ADRs:`, `Lean:`, `Bullets:`, `Skills:`, and `Teammate-model:` lines are read by `/brains:implement --resume`. CLI flags on `--resume` override the persisted values (e.g., `/brains:implement --resume --single`, `--autopilot`, `--lean`, `--teammate-model opus`, or the sugar aliases `--teammate-opus` / `--teammate-sonnet` / `--teammate-haiku`). On first phase-2 run, `Teammate-model:` MAY be left empty if the user has not chosen a tier; `/brains:implement` resolves the default per step 1b and writes the decision back to the plan header before launching the first teammate.

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
