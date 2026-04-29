# BRAINS Phase 3 — Teammate Protocol

Teammates spawned by `/brains:implement` read this file as part of their initial prompt. It defines the teammate-side flow (T1–T6) and the failure-handling summary. It intentionally excludes master-side steps (plan loading, teammate launching, polling) that teammates never execute.

Set the plugin base path:

```bash
BRAINS_PATH="<base directory from header>/../.."
```

## Mode Behavior (inside a teammate)

Modes affect the nurture and secure subagents invoked at the end of the teammate flow, not implementation itself:

| Mode | Flow |
|---|---|
| `--single` | Nurture/secure run without star-chamber |
| `--parallel` (default) | Nurture/secure findings reviewed by star-chamber |
| `--debate` | Nurture/secure run as star-chamber debates |

For `--parallel` and `--debate`, follow `$BRAINS_PATH/references/multi-llm-protocol.md` (or the compact inline excerpt under `--lean`).

## Process

### T1. Read inputs

Read the ADR paths, plan path, phase label, mode, teammate-model, completion marker path, any `model-hint` defaults, and the skills flag (`--skills` / `--no-skills`) from the initial prompt. ADRs MUST be read whole — they are never summarized.

#### T1.1 Skills probe (if `--skills` is set)

If the initial prompt includes `--skills` (and not `--no-skills`), follow `$BRAINS_PATH/references/skills-detection.md` to probe hotskills locally in this teammate session, and `$BRAINS_PATH/references/skills-invocation.md` to derive a query and invoke (or fall back). Each teammate session probes independently — do NOT assume the master's resolved provider state. The vendored `$BRAINS_PATH/references/find-skills.md` is read only if the find-skills fallback fires.

### T2. Grooming (single subagent)

Query the task tracker for tasks matching `brains:topic:<slug>` + `brains:phase-<N>` + `brains:ready-for-grooming` (see `$BRAINS_PATH/references/beads-integration.md` § Task Queries).

Spawn a single grooming subagent. Prompt:
> "Groom these tasks for phase <N>: <task list>. For each task, research the codebase and external docs as needed. Flesh out the description, acceptance criteria, and implementation notes. For each task, emit a `model-hint` field (`sonnet-fine` or `prefer-opus`) in the beads issue record based on complexity: `prefer-opus` when the task introduces new architectural boundaries, touches cross-cutting concerns, or requires non-local reasoning; `sonnet-fine` otherwise. If grooming surfaces new tasks in the same phase scope, add them to beads with labels `brains:topic:<slug>` + `brains:phase-<N>` + `brains:ready-for-grooming`. On completion, swap `brains:ready-for-grooming` for `brains:groomed` on each task.
>
> **Final post-grooming step (per ADR-005 reqs 39-43): GitHub Actions CI status check.** AFTER all label swaps complete, run this check IF (a) `git remote get-url origin` matches `github.com` (substring) AND (b) `command -v gh` succeeds. Both conditions failing → log `CI check skipped: <gh missing | no GitHub remote>` and return.
>
> ```bash
> CURRENT_BRANCH=$(git branch --show-current)
> RUNS=$(gh run list --limit 10 --branch \"$CURRENT_BRANCH\" --json status,conclusion,name,databaseId,createdAt 2>/dev/null)
> ```
>
> For each run with `conclusion in [failure, timed_out, action_required, cancelled]`:
> 1. Determine if the same workflow was already failing on the immediate parent commit: `gh run list --limit 5 --branch \"$CURRENT_BRANCH\" --workflow \"<name>\" --commit $(git rev-parse HEAD~1) --json conclusion,databaseId 2>/dev/null` — if any returned run has `conclusion in [failure, timed_out, action_required, cancelled]`, the failure is **pre-existing** (skip).
> 2. Otherwise (NEW failure), file a beads task:
>    ```
>    bd create \\
>      --title \"Investigate CI failure: <workflow name>\" \\
>      --type=bug \\
>      --priority=2
>    ```
>    Then label it (one `bd label add` call per label):
>    `bd label add <id> brains:topic:<slug>`,
>    `bd label add <id> brains:phase-<N+1>` IF a next phase exists, ELSE `bd label add <id> brains:cleanup`,
>    `bd label add <id> ci-failure`.
>
> MUST NOT wait for in-flight runs to finish (the check is read-only and reports current state). MUST NOT block grooming completion — even if the entire CI block errors, return success."

On grooming failure (3-strike): write `status=failed` to completion marker; halt. CI-check failures (network, gh permission errors) MUST NOT count toward grooming-failure strikes.

### T3. Execution (subagent preferred, not required)

Iterate through groomed tasks in dependency order (beads' `ready` query returns unblocked tasks).

**Dispatch preference:** spawning a fresh subagent (Agent tool) per task is the **preferred** pattern — it isolates context, keeps the teammate's main context clean, and makes per-task failure diagnostics easier. However, subagents are **not required**. When the task is small, tightly coupled to work the teammate just did, or benefits from the teammate's existing context (e.g., a one-line follow-up in a file it just modified), the teammate MAY implement the task directly without spawning a subagent.

**Model selection per task:** the teammate-model chosen by the master (via `--teammate-model` or the Opus-detection prompt) applies by default. For tasks with `model-hint: prefer-opus` in their beads record, spawn the implementation subagent with the orchestrator model (the master's model), even if the user selected a lower tier for general teammate work. `--ignore-model-hints` at master invocation opts out of this escalation.

For each task, regardless of dispatch choice:
1. Gather the task description, relevant ADR excerpts (whole ADR — never summarized), acceptance criteria, and recent commits list.
2. Produce a diff or commits — either via subagent (preferred) or directly.
3. On success: close the bead task. Continue.
4. On failure: follow `$BRAINS_PATH/references/failure-recovery.md` § Task Failure Flow (Phase 3 Execution). Failure counting is per-task (not per-dispatch-mode) — two strikes on the teammate model, then (when escalate-on-retry is enabled, which is the default) a third retry on the orchestrator model before the `brains:needs-human` label is applied. When escalate-on-retry is disabled (`--no-escalate-on-retry` or `brains.escalateOnRetry=false`), the second failure applies `brains:needs-human` directly — the pre-v0.3 behavior.

### T4. Nurture (subagent, mode-aware)

After all phase-<N> implementation tasks are closed (or at pause-timeout — nurture still runs on partial work), invoke `/brains:nurture --scope phase-<N>` as a subagent.

Nurture is responsible for:
- Committing any uncommitted code (atomic commits, conventional-commit messages)
- Updating `.gitignore` for files that shouldn't be tracked
- Reflecting half-complete state in docs if the phase ended early
- Standard behaviors: bug review, test coverage checks, spec drift detection
- Filing follow-up beads tasks labelled `brains:phase-<N+1>` or `brains:cleanup`

**Proactive doc updates during execution (per ADR-005 reqs 27-28):** When implementing tasks that change user-facing behavior or add new options, the teammate MUST update `README.md` and `CHANGELOG.md` entries in the SAME commit as the code change. Docs land with the code, not as trailing cleanup. If no `CHANGELOG.md` exists at the repo root, file a `bd create` follow-up task rather than creating one unilaterally — the project may have a different release-notes convention.

Close the `Nurture: phase <N>` umbrella task on completion.

### T5. Secure (subagent, mode-aware)

Blocked on nurture completion. Invoke `/brains:secure --scope phase-<N>` as a subagent. Same pattern as nurture. Close the `Secure: phase <N>` umbrella task.

### T6. Write completion marker

Write the completion marker JSON file per `$BRAINS_PATH/references/teammate-protocol.md` § Completion Marker Format.

## Task Failure Flow (summary)

Key points:
- First failure → star-chamber re-groom → retry
- Second failure → label `brains:needs-human` with metadata `needs-human-kind` = `failure` | `impossible` | `re-architecture`
- User-response timeout → run nurture+secure on partial work, write paused.md, exit cleanly
- Repeated needs-human cycles are allowed (no automatic limit)
- Escalate-on-retry (default ON; disable via `--no-escalate-on-retry` or `brains.escalateOnRetry=false`): the third retry uses the orchestrator model before `brains:needs-human` is applied.

**Loading `$BRAINS_PATH/references/failure-recovery.md`:**
- **Non-lean (default):** read the full file at initialization and follow it. This preserves v0.2.x behavior.
- **Under `--lean`:** do NOT read the full file at init. Load and follow it on the first task failure. The key points above are sufficient for the happy path.

## Additional Resources

- **`$BRAINS_PATH/references/teammate-protocol.md`** — spawn, sync, marker format
- **`$BRAINS_PATH/references/beads-integration.md`** — task queries, label conventions, fallback
- **`$BRAINS_PATH/references/failure-recovery.md`** — full failure flow (lazy-load on first failure)
- **`$BRAINS_PATH/references/multi-llm-protocol.md`** — star-chamber invocation protocol
