# Teammate Protocol

Shared protocol for launching, synchronizing with, and terminating teammate Claude Code instances during `/brains:implement`. Both `/brains:implement` and `/brains:setup` reference this file.

## Spawn-Mode Detection

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

## Spawn Adapter Contract

Four operations, implemented by each spawn mode:

| Operation | Input | Output | tmux implementation | Agent-teams implementation |
|---|---|---|---|---|
| `spawn(phase_label, initial_prompt)` | phase label, initial prompt | spawn handle (pane id or teammate id) | `tmux split-window "claude '<prompt>'"` | `TeamCreate` + teammate spawn |
| `wait_complete(handle)` | spawn handle | blocks until completion marker or idle signal | poll completion marker file every 15s + poll beads state | await `TeammateIdle` notification + poll beads state |
| `terminate(handle)` | spawn handle | confirmation | `tmux kill-pane -t <pane-id>` | `SendMessage` shutdown request, then cleanup |
| `message(handle, text)` (optional) | spawn handle, message text | delivered / not-supported | not supported — no-op | `SendMessage` |

The `message` operation is optional — tmux mode does not support it, so master logic must not assume it. Any feature that requires mid-flight messaging (e.g., sending a resolved `needs-human` update directly to the running teammate in agent-teams mode) degrades gracefully in tmux mode to the polling-based equivalent.

## Teammate Initial Prompt Template

When master spawns a teammate, the initial prompt MUST include:
- Path(s) to accepted ADR(s) in docs/adr/
- Path to the plan document (docs/plans/<slug>-map.md)
- Phase label (e.g., brains:phase-2)
- Mode flag inherited from master (--single | --parallel | --debate)
- Path to the teammate's completion marker file (docs/plans/.state/<slug>-phase-N-marker.json)
- Behavioral constraints: "Only modify beads tasks labelled brains:topic:<slug> AND brains:phase-N. Cross-phase findings MUST be created with the target phase's label or brains:cleanup. Do not touch the agent-teams native task list if beads is available."

## Completion Marker Format

JSON file at docs/plans/.state/<slug>-phase-N-marker.json:

```json
{
  "status": "complete" | "halted-needs-human" | "failed" | "paused-user-timeout",
  "phase": 2,
  "slug": "health-check-endpoint",
  "finished_at": "2026-04-15T14:32:10Z",
  "notes": "Optional free-form diagnostics"
}
```

Corruption handling: if the file exists but cannot be parsed as JSON, master treats the teammate as crashed (same as a missing marker after idle timeout).

## Master Polling Protocol

In tmux mode:
- Interval: 15 seconds (configurable via settings.local.json)
- Checks: (a) completion marker file, (b) beads task counts for brains:phase-N
- On state change: emit a one-line status update to the master pane (see "Progress Surfacing" below)

In agent-teams mode:
- TeammateIdle notifications are delivered automatically; polling is for beads state changes only.
- Polling interval still applies, at the same 15s default, to pick up state changes that don't trigger TeammateIdle.

## Progress Surfacing

Master's pane prints one-line status updates when beads state changes (or when `TeammateIdle` fires in agent-teams mode). No TUI, no dashboard. Example:

```
[brains] phase 2 — teammate active in pane %5
[brains] phase 2 — 4/7 impl closed, 2 in-progress, 1 blocked
[brains] phase 2 — nurture running (blocked on impl)
[brains] phase 2 — secure running
[brains] phase 2 — complete. 3 cleanup tickets filed.
[brains] phase 3 — launching teammate...
```

## --resume Semantics

/brains:implement --resume:
1. Read docs/plans/<slug>-map.md (by finding the most recent map in docs/plans/ or via --slug arg)
2. Extract Slug, Mode, and Branch fields
3. Optional CLI override: --single | --parallel | --debate takes precedence over persisted Mode
4. Query beads: find the first brains:phase-N label with any open (not closed) tasks
5. Launch a fresh teammate for that phase using the standard spawn flow
