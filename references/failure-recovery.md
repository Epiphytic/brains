# Failure Recovery

Shared protocol for handling task failures, needs-human escalation, user-response timeouts, and resume semantics. Referenced by `/brains:implement` and all teammate-side skills.

## Task Failure Flow (Phase 3 Execution)

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

## Needs-Human Variants

Each task that enters the `brains:needs-human` state carries a `needs-human-kind` metadata field. Three variants:

| Kind | When it's set | Questionnaire prompt to user |
|---|---|---|
| `failure` | Default — task failed twice after star-chamber re-groom | *"Phase N task T-X.Y failed twice. Here is what was tried and what failed: <summary>. How would you like to proceed? You can (a) provide implementation guidance, (b) rewrite the acceptance criteria, (c) mark the task as skipped for this run."* |
| `impossible` | Teammate or star-chamber concludes the task's acceptance criteria cannot be satisfied given the current architecture (e.g., the ADR is wrong, a dependency doesn't exist, a constraint is contradictory) | *"Phase N task T-X.Y appears to be impossible as specified. Here is the reasoning: <summary>. You may know something we don't. Options: (a) provide missing context, (b) adjust the acceptance criteria, (c) mark the task as skipped, (d) escalate to re-architecture."* |
| `re-architecture` | Teammate discovers that an accepted ADR's assumptions are invalid (a library doesn't behave as expected, a constraint was missed, a dependency is deprecated). Filed explicitly with `needs-human-kind=re-architecture` | *"Phase N task T-X.Y surfaces an architecture problem: <summary>. Options: (a) suggest an in-place workaround that avoids re-architecture, (b) stop and run `/brains:brains` again with this context — existing phase-2 task stubs will be cleaned up and regenerated against the new ADR."* |

## Task Failure State Machine

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

Terminal states: `closed`, `skipped` (deliberately not built), `re-architected` (phase 1 was restarted against a new ADR).

## User-Response Timeout

Default: 4 hours from when master posts the questionnaire. Configurable via `settings.local.json` key `brains.userResponseTimeoutSeconds`.

On timeout:
1. Master runs the current phase's nurture and secure subagents against whatever was built so far, even if phase-N implementation tasks are still open. Nurture commits code, updates `.gitignore`, reflects half-complete state in the report.
2. Master writes `docs/plans/<slug>-paused.md` — same structure as the final wrap-up, with YAML frontmatter `paused: true` and a list of incomplete tasks.
3. Master terminates any halted teammates (kills tmux panes; sends shutdown in agent-teams mode).
4. Master exits cleanly. Beads state is preserved. User runs `/brains:implement --resume` when ready.

## Repeated Needs-Human Cycles

By design, a task may cycle through `needs-human → retry-with-guidance → fails-again → needs-human → ...` without limit. This is the user's signal to rework the task or acceptance criteria themselves.

## Impossible-Task Handling

When the star-chamber re-groom (or the subagent itself) concludes a task is structurally impossible with the current ADR, the teammate sets `needs-human-kind=impossible` and files the task via the standard needs-human flow. Master's questionnaire explicitly offers:
- Provide missing context the system doesn't have
- Adjust the acceptance criteria
- Mark the task as `skipped`
- Escalate to `re-architecture`

## Re-Architecture Escalation

When a teammate or user determines that an accepted ADR's assumptions are invalid, the teammate files a task with `needs-human-kind=re-architecture`. Master's questionnaire presents two paths:
1. **In-place workaround.** User provides guidance that avoids re-architecture; task continues with standard retry flow.
2. **Full re-architecture.** Master pauses phase 3, invokes `/brains:brains` again with the existing ADR + rejection reason + partial plan as context. When the new ADR is accepted, phase 2 re-runs and cleans up superseded tasks (see beads-integration.md § Re-Architecture Cleanup). Phase 3 then resumes on the fresh plan.

## Grooming Failures (three-strike rule)

Unlike task execution, the grooming subagent uses the generic three-strike rule from CLAUDE.md:
- Strike 1: retry
- Strike 2: retry with adjusted prompt
- Strike 3: teammate writes `status=failed` to its completion marker; master surfaces error and offers retry or abort.

## Completion Marker Corruption

If a completion marker file exists but cannot be parsed as JSON, treat it as a crashed teammate. Master waits out the idle timeout (default 60 min), then offers restart / skip / abort.
