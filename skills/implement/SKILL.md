---
name: implement
description: This skill should be used when the user asks to "implement the plan", "execute the plan", "start implementation", "build the tasks", "run the teammates", or invokes "/brains:implement". Phase 3 of the BRAINS pipeline: spawns a teammate Claude Code instance per plan-phase via agent-teams (preferred) or tmux (fallback), waits on beads state, handles task failures with two-strike-plus-human-in-loop flow. Supports --single, --parallel (default), and --debate modes for nurture/secure review within each plan-phase, plus an optional --autopilot flag that runs hands-off across phases until a needs-human ticket or direct user intervention stops it. Also supports --resume to pick up after a pause.
user-invocable: true
argument-hint: "[--single|--parallel|--debate] [--autopilot] [--resume] [--slug <slug>]"
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent, TaskCreate, TaskUpdate
---

# BRAINS Phase 3: Implement with Teammates

Launch a fresh Claude Code teammate for each plan-phase, coordinate via beads state, handle failures gracefully. Default mode: `--parallel` (applies to nurture/secure reviews inside each teammate).

Set the plugin base path:

```bash
BRAINS_PATH="<base directory from header>/../.."
```

## Mode Behavior

Modes affect the nurture and secure subagents that run INSIDE each teammate, not implementation itself:

| Mode | Flow |
|---|---|
| `--single` | Nurture/secure run without star-chamber |
| `--parallel` (default) | Nurture/secure findings reviewed by star-chamber |
| `--debate` | Nurture/secure run as star-chamber debates |

For `--parallel` and `--debate`, follow `$BRAINS_PATH/references/multi-llm-protocol.md`.

## Autopilot (`--autopilot`)

Orthogonal flag that composes with any mode. Implementation still follows the standard teammate flow; autopilot only changes master's interaction posture:

- **Start immediately.** Do not prompt for confirmation before launching the first teammate. If chained from `/brains:map --autopilot`, state is inherited.
- **No per-phase confirmation.** Advance from plan-phase N to N+1 automatically once N's completion marker reports `complete`.
- **Only stop when one of these happens:**
  1. The user intervenes (cancels, types `stop`, or sends new instructions).
  2. A `brains:needs-human` task surfaces from a teammate — master pauses and runs the normal needs-human questionnaire flow (see `$BRAINS_PATH/references/failure-recovery.md` § Needs-Human Variants).
  3. All phases complete (natural end).
- **User-response timeout still applies.** If the user does not answer a `needs-human` questionnaire within the configured timeout, master writes `paused.md` and exits as usual. Resuming with `/brains:implement --resume --autopilot` continues in autopilot.
- **Prerequisite failures still stop.** Missing spawn backend (tmux + agent-teams both unavailable) or an unreachable task tracker is a hard stop; autopilot does not suppress these.

Autopilot state is persisted in the plan header (`Autopilot: true`) and read by `--resume`. CLI `--autopilot` / absence-of-flag on resume overrides the persisted value.

## Process (Master-Side)

### 1. Parse arguments

Parse mode, `--autopilot`, `--resume`, and optional `--slug <slug>`. If `--resume` without `--slug`, find the most recent `docs/plans/*-map.md` with open tasks.

### 2. Load plan

Read the plan document. Extract:
- Slug
- Mode (may be overridden by CLI arg)
- Autopilot (may be overridden by CLI arg — presence of `--autopilot` flag sets true; absence on `--resume` keeps the persisted value)
- Branch (warn if current branch differs)
- Plan-phases (enumerate via `brains:phase-*` labels filtered by `brains:topic:<slug>`)

### 3. Prerequisite checks

Spawn mode detection (see `$BRAINS_PATH/references/teammate-protocol.md` § Spawn-Mode Detection):

```bash
if [[ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}" == "1" ]]; then
  SPAWN_MODE="agent-teams"
elif command -v tmux >/dev/null 2>&1; then
  SPAWN_MODE="tmux"
else
  echo "error: /brains:implement requires either tmux or agent-teams."
  echo "Install tmux (apt/brew/pkg install tmux) OR"
  echo "enable agent-teams: set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in settings.json (Claude Code v2.1.32+)."
  exit 1
fi
```

Task tracker: follow `$BRAINS_PATH/references/beads-integration.md` § Tracker Selection.

### 4. Resume (if --resume)

Query the task tracker for the first `brains:phase-N` with any open tasks. Resume at that plan-phase.

### 5. Per-plan-phase loop

For each plan-phase in order:

#### 5a. Launch teammate

Construct the initial prompt per `$BRAINS_PATH/references/teammate-protocol.md` § Teammate Initial Prompt Template — follow the template exactly; do not paraphrase or omit sections. The prompt MUST include accepted ADR paths, the plan path, the phase label (e.g. `brains:phase-2`), the inherited mode flag, the completion marker path under `docs/plans/.state/`, and the behavioral constraints specified in the teammate-protocol reference.

**tmux mode:**
```bash
tmux split-window -h "claude '<initial prompt>'"
```

**agent-teams mode:**
Invoke `TeamCreate` with appropriate lead-provided teammate specification. See `$BRAINS_PATH/references/teammate-protocol.md` for the exact call pattern.

#### 5b. Wait for completion

Poll every 15s (configurable via `settings.local.json` key `brains.pollingIntervalSeconds`):
- Completion marker file at `docs/plans/.state/<slug>-phase-<N>-marker.json`
- Beads task counts: tasks with `brains:topic:<slug>` + `brains:phase-<N>` by status

On state change, emit a one-line status update to the master pane (see `$BRAINS_PATH/references/teammate-protocol.md` § Progress Surfacing).

In agent-teams mode, `TeammateIdle` notifications arrive automatically; still poll beads for state changes that don't trigger idle.

#### 5c. Handle needs-human

When a task acquires the `brains:needs-human` label, dispatch to the handler per `$BRAINS_PATH/references/failure-recovery.md` § Needs-Human Variants. Each variant has its own questionnaire prompt.

In autopilot, a surfaced `brains:needs-human` is one of the three explicit stop conditions. Master still runs the questionnaire flow — autopilot does not suppress the prompt — and resumes autopilot behavior after the user responds.

#### 5d. User-response timeout

If the user does not respond to a questionnaire within the timeout (default 4h, configurable via `settings.local.json` key `brains.userResponseTimeoutSeconds`), follow `$BRAINS_PATH/references/failure-recovery.md` § User-Response Timeout.

#### 5e. Advance

On teammate completion marker status `complete`: close the teammate's pane / shut down the agent-teams teammate, advance to next plan-phase.

### 6. Final cleanup teammate (conditional)

If any `brains:cleanup`-labelled tasks exist: launch one more teammate with phase label `brains:cleanup`, wait for completion, same flow as other phases.

### 7. Wrap-up

If a cleanup teammate ran, read its wrap-up report at `docs/plans/<slug>-wrap-up.md`. Otherwise master writes the wrap-up itself.

Wrap-up structure:

```markdown
# Wrap-up: <topic>

**Slug:** <slug>
**Paused:** false   <!-- true in paused.md variant -->

## Per-Phase Summary
### Phase 1
- Tasks completed: X/Y
- Issues found (nurture): ...
- Issues found (secure): ...

### Phase 2
...

## Outstanding Work
<beads tasks still open, e.g., future/deferred labels>

## Known Gaps and Limitations
<surfaced by nurture/secure>

## Suggested Follow-up Plans
<optional>
```

Summarize the wrap-up to the user and close any remaining teammate panes.

## Process (Teammate-Side)

Teammates read this section as part of their initial prompt.

### T1. Read inputs

Read the ADR paths, plan path, phase label, mode, and completion marker path from the initial prompt.

### T2. Grooming (single subagent)

Query the task tracker for tasks matching `brains:topic:<slug>` + `brains:phase-<N>` + `brains:ready-for-grooming` (see `$BRAINS_PATH/references/beads-integration.md` § Task Queries).

Spawn a single grooming subagent. Prompt:
> "Groom these tasks for phase <N>: <task list>. For each task, research the codebase and external docs as needed. Flesh out the description, acceptance criteria, and implementation notes. If grooming surfaces new tasks in the same phase scope, add them to beads with labels `brains:topic:<slug>` + `brains:phase-<N>` + `brains:ready-for-grooming`. On completion, swap `brains:ready-for-grooming` for `brains:groomed` on each task."

On grooming failure (3-strike): write `status=failed` to completion marker; halt.

### T3. Execution (subagent preferred, not required)

Iterate through groomed tasks in dependency order (beads' `ready` query returns unblocked tasks).

**Dispatch preference:** spawning a fresh subagent (Agent tool) per task is the **preferred** pattern — it isolates context, keeps the teammate's main context clean, and makes per-task failure diagnostics easier. However, subagents are **not required**. When the task is small, tightly coupled to work the teammate just did, or benefits from the teammate's existing context (e.g., a one-line follow-up in a file it just modified), the teammate MAY implement the task directly without spawning a subagent. Pick the lighter-weight option that still leaves the failure/recovery flow auditable.

For each task, regardless of dispatch choice:
1. Gather the task description, relevant ADR excerpts, acceptance criteria, and recent commits list.
2. Produce a diff or commits — either via subagent (preferred) or directly.
3. On success: close the bead task. Continue.
4. On failure: follow `$BRAINS_PATH/references/failure-recovery.md` § Task Failure Flow (Phase 3 Execution). Failure counting is per-task (not per-dispatch-mode) — two strikes total before `brains:needs-human`.

### T4. Nurture (subagent, mode-aware)

After all phase-<N> implementation tasks are closed (or at pause-timeout — nurture still runs on partial work), invoke `/brains:nurture --scope phase-<N>` as a subagent.

Nurture is responsible for:
- Committing any uncommitted code (atomic commits, conventional-commit messages)
- Updating `.gitignore` for files that shouldn't be tracked
- Reflecting half-complete state in docs if the phase ended early
- Standard behaviors: bug review, test coverage checks, spec drift detection
- Filing follow-up beads tasks labelled `brains:phase-<N+1>` or `brains:cleanup`

Close the `Nurture: phase <N>` umbrella task on completion.

### T5. Secure (subagent, mode-aware)

Blocked on nurture completion. Invoke `/brains:secure --scope phase-<N>` as a subagent. Same pattern as nurture. Close the `Secure: phase <N>` umbrella task.

### T6. Write completion marker

Write the completion marker JSON file per `$BRAINS_PATH/references/teammate-protocol.md` § Completion Marker Format.

## Task Failure Flow

Follow `$BRAINS_PATH/references/failure-recovery.md` — entire file. Key points:
- First failure → star-chamber re-groom → retry
- Second failure → label `brains:needs-human` with metadata `needs-human-kind` = `failure` | `impossible` | `re-architecture`
- User-response timeout → run nurture+secure on partial work, write paused.md, exit cleanly
- Repeated needs-human cycles are allowed (no automatic limit)

## Additional Resources

- **`$BRAINS_PATH/references/teammate-protocol.md`** — spawn, sync, marker format
- **`$BRAINS_PATH/references/beads-integration.md`** — task queries, label conventions, fallback
- **`$BRAINS_PATH/references/failure-recovery.md`** — failure flow, needs-human variants, state machine
- **`$BRAINS_PATH/references/multi-llm-protocol.md`** — star-chamber invocation protocol
