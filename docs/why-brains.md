# Why BRAINS?

The design rationale behind the three-phase pipeline, just-in-time grooming, per-phase nurture and secure review, and star-chamber gating at every major decision point. Each choice addresses a specific failure mode observed in unstructured LLM coding workflows, and each trades a small amount of up-front token spend for a much larger reduction in rework.

## The underlying bet: alignment up front beats instruction volume later

Humans are **unevenly good at giving context to LLMs.** Some prompts are crisp and surgical. Most aren't. And the dominant failure mode of agentic coding isn't "the LLM didn't try hard enough" — it's "the instructions didn't say what the user actually wanted, or left ambiguity that the LLM resolved in a direction the user didn't want." The agent then builds thousands of tokens' worth of wrong code, the user notices, the agent throws it away, and builds it again.

Phase 1 (`/brains:brains`) is not a productivity tax. It is a **forced alignment exercise.** By requiring:

- An initial codebase research pass (not just vibes),
- 2–4 architectural questions with explicit pros and cons framed by the LLM,
- A star-chamber review pass that challenges framings the local LLM would have accepted on its own,

…the plugin converts a vague user intent into an RFC 2119 ADR with testable MUST/SHOULD/MAY requirements. By the time the first line of implementation is written, the coding agent is executing against a specification the user has already read and approved.

The key move is that **the entire execution plan going to the coding agents is LLM-generated, just-in-time, based on the current state of the codebase and the specific inputs from the human in the loop.** The forcing factor is asking the user targeted questions — not asking them to write a spec. Humans are better at reacting to concrete options with pros and cons than at authoring comprehensive prompts from a blank page. BRAINS leans into that asymmetry.

Result: the plan that reaches coding agents carries the user's actual intent, not the user's best attempt at describing their intent. The "build it, realize it was wrong, throw it away, rebuild" cycle that dominates token spend in unstructured workflows shrinks dramatically.

## Just-in-time grooming

Tasks are created in phase 2 as **stubs** — intentionally under-specified. Each phase 3 teammate runs a grooming pass on its own tasks *immediately before execution*, not upfront.

Why this matters:

- The codebase at grooming time is the codebase at execution time. No drift between what the plan assumed and what the repository actually looks like.
- The grooming subagent has the fresh context of the ADR and the current phase's scope — nothing else to confuse it.
- Stubs are cheap to regenerate. When phase N's execution reveals that phase N+1's stubs were misspecified, rewriting stubs costs little. Rewriting a fully-groomed detailed plan costs a lot.

This is the opposite of the "plan the whole thing in detail up front" pattern. Upfront detail in a multi-phase plan is **almost always wrong by the time you get to it**, and the tokens spent generating that detail are wasted.

## Sequential phases avoid cross-phase rework

Phases run in order, not in parallel, and each has a clear boundary.

When phases overlap or run concurrently:

- Changes made by phase A on files that phase B assumed to be stable cause B to rework.
- Two agents editing the same module produce merge conflicts that require human intervention.
- Tests written in one phase against code being modified in another fail unpredictably.

Sequential phases trade throughput for **predictability and low retry cost**. Every phase starts with a fresh, committed baseline. Phase N+1 never has to guess what phase N was "about to" do.

## Per-phase nurture and secure review

At the end of every plan-phase, two dedicated review passes run inside the teammate:

- **Nurture** — atomic commits, `.gitignore` hygiene, test coverage, spec-drift detection, follow-up task filing.
- **Secure** — security review over the code this phase actually produced.

Why per-phase, not once at the end?

- Reviewing 1/N of the changes at a time gives much better per-review signal. A reviewer looking at a full three-phase diff loses the causal story; a reviewer looking at one phase sees a coherent unit of work.
- Nurture-discovered issues get fixed before the next phase builds on top of the flawed foundation. Bad code caught late is exponentially more expensive than bad code caught early.
- Secure runs on actually-implemented code, not on design documents. Findings are concrete ("this function is vulnerable to X") instead of speculative ("the design could hypothetically enable X").

## Focused teammate context: ADR + this phase only

Each phase 3 teammate receives **only**:

- The accepted ADR(s),
- The plan document,
- The tasks labelled with its specific phase.

Not: other phases' tasks, prior phases' diffs beyond what the ADR references, or the full history of deliberation that produced the plan.

This is a deliberate **context budget.** A teammate staring at the whole plan is worse per token than a teammate staring at one phase's slice. Less context means fewer distractions, higher attention density on what matters, and lower per-task token spend. A smaller context window also gives the teammate more headroom for iteration on hard tasks before compaction kicks in.

## ADRs improve during the coding cycle

An ADR that survives contact with implementation unchanged is rare. BRAINS makes the feedback path explicit:

- A teammate that hits an invalid ADR assumption files a task with `needs-human-kind=re-architecture`.
- Master surfaces the finding to the user with two options: an in-place workaround, or restart phase 1 with the existing ADR plus the concrete failure as new context.
- If the user chooses re-architecture, a new ADR is synthesized against the real, now-partially-implemented codebase — not the imagined one from the original phase 1. Existing phase-2 task stubs get cleaned up and regenerated against the new ADR.

**ADRs are living artifacts**, not frozen decisions. This avoids the classic "we've committed to an architecture we know is wrong but we'll ride it out to avoid re-planning" death spiral. The cost of re-architecture is real, but almost always lower than the cost of continuing to build on a broken foundation.

## Star chamber at every decision point and whenever the LLM is stuck

The star chamber (multi-LLM council) is invoked at the points where single-model reasoning most often fails:

- **Architecture synthesis** (phase 1) — reviews for soundness, missing concerns, version choices, testability.
- **Plan review** (phase 2) — reviews the stub-level plan for ordering, sizing, coverage, phasing.
- **Nurture and secure** (phase 3) — reviews findings and suggested fixes.
- **First-failure re-groom** (phase 3) — when a task fails once, the council re-grooms the task description and acceptance criteria before retry.

Why multiple models, not just one more careful prompt? Because single-model reasoning has consistent blind spots. A second model — particularly from a different family — catches the class of mistakes the first model is temperamentally prone to making. The cost is an extra round of council token spend; the saving is the rework that would have happened when the first model's blind spot hit production code.

## Fewer human-in-the-loop touchpoints

The star chamber is deliberately inserted **before** the `brains:needs-human` escalation:

- First task failure → star-chamber re-groom → retry. The human is not notified.
- Only if the re-grooming-informed retry also fails does the task acquire the `brains:needs-human` label and surface to the user.

This means the user is interrupted only for problems that two independent LLMs couldn't resolve together. Most transient failures — flaky tests, a misread API, a missing import — get caught and fixed by the council without ever reaching the user. When the user *is* interrupted, they're reading a questionnaire that already includes the council's analysis of what went wrong and a menu of viable options, not a raw stack trace or a vague "I got stuck."

The net effect: less interrupt fatigue, higher signal per interruption, and faster resolution when human judgment genuinely is the bottleneck.

## Summary table

| Design choice | What it prevents | How it saves tokens |
|---|---|---|
| Forced brainstorming + star-chamber at phase 1 | Vague, unaligned instructions reaching coding agents | Eliminates rewrite-from-scratch cycles when the LLM misreads intent |
| Just-in-time grooming | Stale, drift-prone upfront plans | Stubs regenerate cheaply; fully-groomed plans don't |
| Sequential phases | Cross-phase interference, merge conflicts | No retry cost from concurrent edits |
| Per-phase nurture and secure | Late-stage discovery of foundational bugs | Early fixes are cheaper than late ones; review signal per token is higher |
| Focused teammate context (ADR + this phase) | Distraction, wasted attention, early compaction | Lower per-task token spend; more headroom for hard tasks |
| Living ADRs, re-architecture escalation | Building on architecture known to be wrong | Re-architecture cost < sunk-cost continuation |
| Star chamber at every decision point | Single-model blind spots compounding into rework | Catches rework sources before they spread |
| Star chamber before human escalation | Interrupt fatigue, low-signal pages | Humans only see what two independent LLMs couldn't jointly solve |

## When BRAINS is not the right tool

BRAINS is not faster for trivial tasks. Typo fixes, one-line config changes, and other work where the cost of rework is small don't benefit from three phases and multi-LLM review — the overhead dominates.

BRAINS is specifically faster (and cheaper) for tasks where **rework cost dominates raw execution cost.** That is most non-trivial real-world tasks: anything touching more than one file, anything with unclear requirements, anything where the architecture has to survive review. For those, the up-front token investment in alignment and structure pays back many times over.
