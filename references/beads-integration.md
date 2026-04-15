# Beads Integration

Shared protocol for how BRAINS skills interact with the beads task tracker. Referenced by `/brains:map`, `/brains:implement`, and all teammate-side skills.

## Tracker Selection

Beads is the authoritative task tracker whenever it is available. Selection logic:

- **Beads installed and initialized:** use it.
- **Beads installed but uninitialized:** run `bd init --local` automatically and announce: *"Initializing beads for this repository (local mode)."* No prompt.
- **Beads unavailable, agent-teams mode active:** fall back to agent-teams' built-in task list. Announce to the user: *"beads is not installed. Falling back to the agent-teams task list. Cross-session recovery, dependency queries, and label filtering are degraded in this mode. Install beads for the full experience."*
- **Beads unavailable, tmux mode:** fall back to `TaskCreate` / `TaskUpdate`. Same one-line awareness note as above, adjusted for the tracker.

## Label Namespace

All BRAINS-managed labels are prefixed `brains:`. Full set:

- `brains:topic:<slug>` — applied to every task created by the pipeline. Slug is derived from the topic (kebab-case, lowercase). Enables multiple concurrent BRAINS pipelines in the same repo without state tangling.
- `brains:phase-1`, `brains:phase-2`, ..., `brains:phase-N` — plan-phase membership.
- `brains:ready-for-grooming` — newly created by `/brains:map`; waiting for a teammate to groom.
- `brains:groomed` — grooming complete; task ready for execution.
- `brains:needs-human` — task failed twice or escalated; pending user input. See `needs-human-kind` metadata for variant.
- `brains:cleanup` — a finding with no natural next phase; handled by the final cleanup teammate.
- `brains:superseded` — task from a prior plan that was replaced by a re-architecture run.
- Optional domain labels (e.g., `ui`, `backend`, `auth`) inferred from the ADR — unprefixed, not managed by BRAINS.

## Topic Slugs and Branch Integration

When phase 2 runs, it derives the topic slug from the user's original prompt (e.g., *"add a health-check endpoint"* → `health-check-endpoint`). The slug is used for:
- All `brains:topic:<slug>` task labels
- File names: `docs/plans/YYYY-MM-DD-<slug>-map.md`, etc.
- Optional branch creation

If the user is currently on `main` / `master` / `develop` (or any branch configured as a base branch in `settings.local.json`), phase 2 offers to create a `brains/<slug>` branch before proceeding. If the user declines, phase 2 continues on the current branch. If the user is already on a non-base branch, phase 2 uses the existing branch without prompting.

## Task Lifecycle

```
created by /brains:map:    [brains:topic:<slug>, brains:ready-for-grooming, brains:phase-N, <domain>...]
after grooming:             [brains:topic:<slug>, brains:groomed, brains:phase-N, <domain>...]
after execution:            status=closed  (labels preserved for audit)
```

Additional state metadata stored on beads tasks:
- `needs-human-kind` — one of `failure`, `impossible`, `re-architecture`. Set when the task enters the needs-human state.

## Initialization

Beads is initialized automatically if available but uninitialized:

```bash
if command -v bd >/dev/null 2>&1; then
  if ! bd status >/dev/null 2>&1; then
    bd init --local
    echo "Initializing beads for this repository (local mode)."
  fi
fi
```

## Task Creation (phase 2)

For each plan-item in each plan-phase:

```bash
bd create \
  --title "<task title>" \
  --label brains:topic:<slug> \
  --label brains:ready-for-grooming \
  --label brains:phase-<N> \
  --label <domain>  # optional; repeat for multiple domains
```

Dependencies: use `bd dep add <task-id> --blocked-by <other-task-id>`.

Umbrella tasks per phase:
- Nurture task: `brains:topic:<slug>`, `brains:phase-<N>`, title `Nurture: phase <N>`, blocked by all implementation tasks in phase N.
- Secure task: `brains:topic:<slug>`, `brains:phase-<N>`, title `Secure: phase <N>`, blocked by the Nurture task.

Final plan-phase also gets:
- Cleanup task: `brains:topic:<slug>`, `brains:cleanup`, title `Cleanup: topic <slug>`, blocked by all phase-N Secure tasks.

## Task Queries (teammate-side)

Get ready-to-groom tasks for this phase:

```bash
bd list --label brains:topic:<slug> --label brains:phase-<N> --label brains:ready-for-grooming --status pending
```

Get ready-to-execute (groomed) tasks:

```bash
bd list --label brains:topic:<slug> --label brains:phase-<N> --label brains:groomed --status pending
```

Mark a task as groomed:

```bash
bd label remove <task-id> brains:ready-for-grooming
bd label add <task-id> brains:groomed
```

Close a task on successful completion:

```bash
bd close <task-id> --comment "Completed by teammate subagent."
```

## Re-Architecture Cleanup

This cleanup runs only when phase 2 is being re-run because phase 3 escalated a `needs-human-kind=re-architecture` (see phase 3 failure flow). Before creating new tasks, find all beads tasks with the matching `brains:topic:<slug>` label and a creation timestamp before the new ADR's date, and close them with a `brains:superseded` label. This preserves audit history without polluting the active task list. Implementation work already completed on superseded tasks remains in git history; what to do with it is up to the new plan.

Command sketch:

```bash
# Find superseded tasks (older than new ADR date, matching topic)
SLUG="<slug>"; NEW_ADR_DATE="<YYYY-MM-DD>"
bd list --label brains:topic:$SLUG --status open --format json | \
  jq -r ".[] | select(.created_at < \"$NEW_ADR_DATE\") | .id" | \
  while read -r id; do
    bd label add "$id" brains:superseded
    bd close "$id" --comment "Superseded by re-architecture on $NEW_ADR_DATE"
  done
```

## Fallback to Agent-Teams Task List

If beads is unavailable AND agent-teams mode is active, use agent-teams' built-in task list (TaskCreate/TaskUpdate/TaskList). Map beads concepts to these tools:

| Beads | Agent-teams fallback |
|---|---|
| label brains:topic:<slug> | Task title prefix `[<slug>]` |
| label brains:phase-N | Task title prefix `[phase-N]` |
| label brains:ready-for-grooming | activeForm "Awaiting grooming" |
| brains:groomed | activeForm "Groomed" |
| needs-human + metadata | Task description prepended with `NEEDS HUMAN (<kind>): ` |
| dependencies | `addBlockedBy` |

Announce once, at phase 2 start: "beads is not installed. Falling back to the agent-teams task list. Cross-session recovery, dependency queries, and label filtering are degraded in this mode. Install beads for the full experience."

## Fallback to TaskCreate (tmux mode without beads)

Same semantics as agent-teams fallback above. Announce once at phase 2 start.
