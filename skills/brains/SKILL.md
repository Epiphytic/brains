---
name: brains
description: This skill should be used when the user asks to "run the brains pipeline", "start the brains workflow", "plan and implement from scratch", "do an ADR", "start with brainstorming", or invokes "/brains:brains". Phase 1 of the BRAINS pipeline: interactive research, question generation, questionnaire, architecture synthesis, and ADR production. Supports --single, --parallel (default), and --debate modes, and an optional --autopilot flag that auto-chains into hands-off map + implement. Chains into /brains:map at the user gate.
user-invocable: true
argument-hint: "[--single|--parallel|--debate] [--autopilot] [--rounds N] [topic]"
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent, WebFetch, WebSearch, TaskCreate, TaskUpdate
---

# BRAINS Phase 1: Interactive Architecture Loop

Drive a user prompt through initial research, a 2-4 question interactive questionnaire, and an ADR with RFC 2119 requirements. Default mode: `--parallel` with star-chamber review.

Set the plugin base path:

```bash
BRAINS_PATH="<base directory from header>/../.."
```

## Mode Behavior

| Mode | Question generation | Architecture review |
|---|---|---|
| `--single` | Subagent only | Subagent only |
| `--parallel` (default) | Subagent + star-chamber; merge and de-duplicate | Star-chamber reviews after synthesis |
| `--debate` | Subagent + star-chamber debate across rounds | Star-chamber debates across rounds |

For `--parallel` and `--debate`, read and follow `$BRAINS_PATH/references/multi-llm-protocol.md`.

## Hard Gate

Do NOT chain into `/brains:map` until an ADR has been written and the user has accepted it.

## Process

### 1. Parse arguments and derive topic

Parse `--single` / `--parallel` / `--debate`, `--autopilot`, `--rounds N`, and the topic string. If no topic is provided, ask the user.

`--autopilot` is an orthogonal flag that composes with any mode. When present, it does not change question-generation, synthesis, or review behavior — those still follow the selected mode. It only pre-selects **option 2** at the ADR gate (see step 9) and propagates to downstream phases.

### 2. Initial research (subagent)

Spawn a research subagent scoped to the user's prompt. Use `Agent` with `subagent_type=feature-dev:code-explorer` when the prompt involves existing code; otherwise use a generic research agent. The subagent prompt MUST instruct it to produce:
- Current stable versions of relevant libraries (SHOULD-level provenance, not a lock)
- Deprecated APIs to avoid
- Idiomatic patterns in the codebase or ecosystem
- Prior art (blog posts, reference implementations)

Output path: `docs/plans/YYYY-MM-DD-<slug>-research.md` (committed to git).

If a research document from the same slug already exists and is younger than 24h, skip this step and reuse it.

### 3. Question generation (mode-dependent)

You are aiming for generally 2-4 questions, each with explicit pros and cons, informed by the user's prompt and the research document from step 2. Each question should frame a real architectural choice — not a preference poll. Write pros and cons that would survive adversarial review.

Mode-specific procedure:

- **`--single`:** spawn a single subagent and instruct it to generate the 2-4 question set with pros and cons. Use its output directly.
- **`--parallel` (default):** spawn the subagent as in `--single` and concurrently invoke the star-chamber to produce its own candidate question set. Follow the parallel-mode protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`. After both return, merge the two sets: de-duplicate semantically equivalent questions (not just string matches), keep the strongest framing and pro/con pairing for each, and drop questions that are strictly weaker variants.
- **`--debate`:** spawn the subagent and star-chamber and run them across `--rounds N` (default 2) or until convergence, following the debate protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`. Each round, both sides see the other's questions and critique / revise. Stop early if both sides converge on the same set.

Present the final question set to the user before starting the questionnaire so they can reject or reorder.

### 4. Offer visual companion (own message)

If any anticipated question would be clearer with a visual (layout comparison, state-machine mockup, component diagram), offer the browser-based visual companion in its own message. See `$BRAINS_PATH/skills/brains/references/visual-companion.md` for the detailed guide. This is a per-question tool, not a mode — accept once, then decide per-question whether to use terminal or browser.

Offer prompt:
> "Some of what we're working on might be easier to explain if I can show it to you in a web browser. I can put together mockups, diagrams, comparisons, and other visuals as we go. This feature is still new and can be token-intensive. Want to try it? (Requires opening a local URL)"

### 5. Interactive questionnaire

For each generated question:
1. Present the question with pros and cons.
2. Accept the user's answer.
3. Adapt the remaining question set based on new information.
4. If an answer (a) contradicts a research finding, (b) introduces a new architectural dimension, or (c) renders remaining questions interdependent in unforeseen ways: re-engage the star-chamber for question review; optionally spawn a fresh research subagent for the new dimension.

### 6. Architecture synthesis

Produce the full architecture with up-to-date standards. Version specification is SHOULD-level — prefer MAJOR.MINOR for semver libraries; use the library's native scheme for non-semver.

### 7. Architecture review (mode-dependent)

The review pass sits between synthesis and ADR generation. What happens here depends on the mode:

- **`--single`:** skip review entirely. Present the synthesized architecture directly to the user for the gate in step 9.
- **`--parallel` (default):** invoke the star-chamber to review the synthesized architecture, following the parallel-mode protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`. Collect feedback across categories (soundness, version choices, missing concerns, testability). Present the feedback to the user alongside your recommendation and integrate accepted items into the architecture before writing the ADR.
- **`--debate`:** run the star-chamber in debate mode across `--rounds N` (default 2) or until convergence, following the debate protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`. Providers see each other's critiques and respond. Integrate the converged feedback (with user approval on contested items) before writing the ADR.

### 8. ADR generation

Produce one or more ADRs in `docs/adr/`. Filename format: `YYYY-MM-DD-NNN-<title>.md` where NNN is a globally sequential number (check `docs/adr/` for the next available number).

ADR structure:

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
<Testable MUST/SHOULD/MAY statements derived from the decision>
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
<mermaid block, if warranted: ≥3 components with ≥2 relationships, or ≥1 state machine>

## Consequences
<What changes as a result>

## Council Input
<Summary of star-chamber feedback, when applicable>
```

Use RFC 2119 MUST/MUST NOT/SHOULD/SHOULD NOT/MAY language in the Requirements section. Include a mermaid diagram if the ADR has three or more components with two or more relationships, or at least one state machine.

### 9. User gate

Present the ADR(s) to the user. If `--autopilot` was passed at skill launch, do NOT prompt — auto-select option 2 and proceed. Otherwise prompt the user to choose exactly one of:

1. **Accept ADR(s), push to origin, and chain into `/brains:map`** (planning mode) with the inherited mode flag.
2. **Accept ADR(s), push to origin, and chain into `/brains:map --autopilot`** (hands-off planning + implementation) with the inherited mode flag.
3. **Accept ADR(s), push to origin, and stop.** No further phases run.
4. **Reject ADR(s) and stop.** Record the rejection reason (free-form); do not loop.
5. **Provide fixes or alternate instructions.** User writes concrete edits or new guidance. Treat the text as input to a re-run of step 6 (architecture synthesis) and step 7 (architecture review) with the current ADR draft + user guidance appended to context. Re-present at this gate when the revised ADR is ready.

#### Handling options 1-3: commit and push

Before chaining (options 1/2) or stopping (option 3), commit the newly produced ADR files (and the research document from step 2 if not already committed) and push to origin. Use conventional-commit prefix `docs(adr):`.

```bash
# Stage and commit (files listed explicitly — never `git add .`)
git add docs/adr/YYYY-MM-DD-NNN-<slug>.md
[[ -f docs/plans/YYYY-MM-DD-<slug>-research.md ]] && git add docs/plans/YYYY-MM-DD-<slug>-research.md
git commit -m "docs(adr): add ADR-NNN <title>"

# Push — set upstream if the branch has none
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git push
else
  git push -u origin "$(git branch --show-current)"
fi
```

If the push fails (auth, protected branch, network), surface the error to the user. Do NOT bypass hooks or force-push. Offer: (a) retry after the user resolves the issue, (b) skip push and continue locally (options 1/2 still chain; option 3 still stops), (c) abort.

#### Handling option 4: terminal rejection

Write the rejection reason to `docs/plans/YYYY-MM-DD-<slug>-rejected.md` (single-paragraph note), then stop. Do not commit.

#### Handling option 5: user-provided fixes

Capture the user's text verbatim. Append to context as `User-provided fixes:\n<text>` and re-run step 6 (synthesis) then step 7 (review), producing a revised ADR. Re-present the revised ADR at this gate.

## Phase Transition

After the ADR is accepted (option 1 or 2) and the commit+push succeeds:

- **Option 1:** > "Phase 1 complete. ADR(s) pushed to origin. Chaining into phase 2 (`/brains:map`) with mode `<mode>`."
  Invoke `/brains:map` directly — do not wait for further user input.
- **Option 2:** > "Phase 1 complete. ADR(s) pushed to origin. Chaining into phase 2 (`/brains:map --autopilot`) with mode `<mode>`."
  Invoke `/brains:map --autopilot` directly — subsequent phases will not prompt the user unless a `brains:needs-human` escalation surfaces.
- **Option 3:** > "Phase 1 complete. ADR(s) pushed to origin. Stopping — invoke `/brains:map` when ready to plan."

## Additional Resources

- **`$BRAINS_PATH/references/multi-llm-protocol.md`** — shared multi-LLM invocation protocol
- **`$BRAINS_PATH/skills/brains/references/visual-companion.md`** — visual companion guide (browser-based mockups, diagrams, comparisons)
