---
name: brains
description: This skill should be used when the user asks to "run the brains pipeline", "start the brains workflow", "plan and implement from scratch", "do an ADR", "start with brainstorming", or invokes "/brains:brains". Phase 1 of the BRAINS pipeline: interactive research, question generation, questionnaire, architecture synthesis, and ADR production. Supports --single, --parallel (default), and --debate modes, and an optional --autopilot flag that auto-chains into hands-off map + implement. Chains into /brains:map at the user gate.
user-invocable: true
argument-hint: "[--single|--parallel|--debate] [--autopilot] [--accept-adrs] [--lean] [--grill] [--skills|--no-skills] [--document-mode|--no-document-mode] [--rounds N] [--max-diagrams N] [--no-diagram] [--diagram <type>] [topic]"
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

For `--parallel` and `--debate`, read and follow `$BRAINS_PATH/references/multi-llm-protocol.md`. Under `--lean`, read the compact excerpt at `$BRAINS_PATH/references/multi-llm-protocol-compact.md` instead; consult the full file only for debate-round synthesis, error handling, or unusual prerequisite failures.

## Hard Gate

Do NOT chain into `/brains:map` until an ADR has been written and the user has accepted it.

## Process

### 1. Parse arguments and derive topic

Parse `--single` / `--parallel` / `--debate`, `--autopilot`, `--accept-adrs` / `--no-accept-adrs`, `--lean`, `--grill`, `--skills` / `--no-skills`, `--document-mode` / `--no-document-mode`, `--rounds N`, `--max-diagrams N`, `--no-diagram`, `--diagram <type>`, and the topic string. If no topic is provided, ask the user.

**Flag resolution for `--skills`, `--grill`, and `--accept-adrs`** (per ADR-005 reqs 18-19, 34-35): all three are boolean orthogonal flags resolved through a 4-layer precedence chain. For each flag, walk the chain top-to-bottom and stop at the first definitive value:

1. **Explicit CLI flag** — `--skills` / `--no-skills` (or `--grill` / `--no-grill`, or `--accept-adrs` / `--no-accept-adrs`) on the command line wins.
2. **`.claude/brains.local.md` Flags table** — a row matching the flag key with `true` or `false` in the "Project Default" column.
3. **`~/.config/brains/defaults.json` `flags` object** — `flags.skills` / `flags.grill` / `flags.accept_adrs` boolean.
4. **Built-in default** — `false`.

Empty/missing rows in the local Flags table fall through to the global file; missing keys in the global `flags` object fall through to the built-in default. CLI `--no-skills` MUST override a `flags.skills: true` global; CLI `--no-grill` MUST override a `flags.grill: true` global; CLI `--no-accept-adrs` MUST override a `flags.accept_adrs: true` global.

When the resolved value of `--skills` is `true`, this skill follows `$BRAINS_PATH/references/skills-detection.md` (probe procedure for hotskills) and `$BRAINS_PATH/references/skills-invocation.md` (query derivation, search/activate/invoke sequence, and the find-skills fallback). The vendored `$BRAINS_PATH/references/find-skills.md` is read only when the fallback fires (lazy-load per ADR-005 req 29).

**Flag resolution for `--document-mode`** (per ADR-006 req 2, using the same 4-layer precedence chain as ADR-005 reqs 18-19): `--document-mode` is a boolean orthogonal flag. Walk the chain top-to-bottom and stop at the first definitive value:

1. **Explicit CLI flag** — `--document-mode` / `--no-document-mode` on the command line wins.
2. **`.claude/brains.local.md` Flags table** — a row matching the flag key `document_mode` with `true` or `false` in the "Project Default" column.
3. **`~/.config/brains/defaults.json` `flags` object** — `flags.document_mode` boolean.
4. **Built-in default** — `false`.

Empty/missing rows in the local Flags table fall through to the global file; a missing `flags.document_mode` key falls through to the built-in default. CLI `--no-document-mode` MUST override a `flags.document_mode: true` global. The resolved value is consumed by the Step-1 pre-flight delegation guard below. `--document-mode` MUST NOT propagate to `/brains:map` or `/brains:implement` (ADR-006 req 5): once the guard routes to `/brains:document` there are no downstream phases to receive it, and when the guard does not fire the flag has no further effect.

Diagram flag rules: `--no-diagram` suppresses all auto-trigger; `--diagram <type>` forces that type and overrides `--max-diagrams` (valid types: `flowchart`, `state`, `c4`, `er`, `sequence`; error with list of valid types if unknown); `--max-diagrams N` must be 1–5 (error if out of range, default 1). These flags are stored and passed to step 8.

`--autopilot` is an orthogonal flag that composes with any mode. When present, it does not change question-generation, synthesis, or review behavior — those still follow the selected mode. It propagates to downstream phases. By itself, `--autopilot` does NOT auto-accept the ADR gate (per ADR-005 req 33) — the gate is presented normally and awaits user input. To skip the ADR gate as well, combine with `--accept-adrs`.

`--accept-adrs` is an orthogonal flag (per ADR-005 reqs 34-35). When `--autopilot --accept-adrs` are BOTH resolved-true at step 9, the skill auto-selects **option 2** at the ADR gate and chains into `/brains:map --autopilot`. With `--autopilot` alone (no `--accept-adrs`), the gate is presented normally — autopilot semantics resume only AFTER the user accepts. The resolved value is persisted in the plan header (`Accept-ADRs:`) so `/brains:implement --resume` honors it consistently with `Autopilot:`.

`--lean` is an orthogonal flag that composes with any mode and with `--autopilot`. When present, activate the token-efficiency path (see `$BRAINS_PATH/manifests/phase-1-brains.md` for the role manifest): use the compact multi-llm-protocol excerpt inline rather than reading the full reference; append a `Research-Summary` block to the plan header at step 2; otherwise behave identically. Default off (byte-identical to prior behavior). `--lean` propagates to downstream phases.

`--grill` is a **strategy modifier** — orthogonal to `--single`, `--parallel`, `--debate`, `--lean`, and `--autopilot`. All combinations are valid. When present, it lifts the 2–4 question cap and applies the relentless-interview questionnaire policy defined in `$BRAINS_PATH/skills/brains/references/grill-protocol.md`. `--grill` applies to phase-1 steps 3 and 5 only; it does NOT propagate to `/brains:map` or `/brains:implement`, and it MUST NOT be forwarded to any chained skill.

#### Document-mode pre-flight delegation guard (per ADR-006 reqs 3-5)

Run this guard at the **top of Step 1, before any research (step 2) or questionnaire work**, immediately after flag resolution above. It is the one place that can route before any phase begins.

1. **Run the eligibility probe.** Follow `$BRAINS_PATH/skills/document/references/eligibility-detection.md`: deterministic bash classifies and counts the canonical changed set (unstaged ∪ staged ∪ untracked-not-ignored) against the versioned document allow-list, and the main LLM resolves in-scope target documents from the prompt (greenfield) and follows document links with `test -f` confirmation. This yields whether the change is **document-only** (zero non-document files) and **eligible** (≤ 4 target documents AND ≤ 10 unique on-disk dependents).

2. **Delegate to `/brains:document`** when EITHER (a) `--document-mode` resolves true, OR (b) the change is auto-detected as document-only AND eligible. Forward the resolved mode flag, `--autopilot`, `--lean`, and `--teammate-model` verbatim. Invoke directly:

   ```
   /brains:document <resolved-mode-flag> [--autopilot] [--lean] [--teammate-model <model>] <topic>
   ```

   After delegating, **do NOT continue this pipeline** — `/brains:document` owns the entire abbreviated spine (eligibility gate, lightweight research, questionnaire, slim ADR, inline edits, direct council review, inline commit). Do not run steps 2–9 here.

3. **Apply the threshold and asymmetric-override rules from the eligibility-detection reference** when the change is ineligible: interactive **warn-and-ask** / `--autopilot` **detect-then-fallback** with a loud notice for oversized-but-document-only scopes; **hard-refuse** under a manual `--document-mode` override when non-document code files are present (fenced/example code inside a document never triggers refusal). When detection routes to the full pipeline (no delegation, or a fallback), continue with step 2 below.

`--document-mode` is consumed entirely by this guard and the delegated `/brains:document` spine; it is **never** forwarded to `/brains:map` or `/brains:implement` (req 5).

### 2. Initial research (subagent)

Spawn a research subagent scoped to the user's prompt. Use `Agent` with `subagent_type=feature-dev:code-explorer` when the prompt involves existing code; otherwise use a generic research agent. The subagent prompt MUST instruct it to produce:
- Current stable versions of relevant libraries (SHOULD-level provenance, not a lock)
- Deprecated APIs to avoid
- Idiomatic patterns in the codebase or ecosystem
- Prior art (blog posts, reference implementations)

Output path: `docs/research/YYYY-MM-DD-<slug>-research.md` (committed to git).

If a research document from the same slug already exists and is younger than 24h, skip this step and reuse it.

**Under `--lean`:** after writing the research document, produce a compact `research-summary` YAML block following the schema at `$BRAINS_PATH/skills/brains/references/research-summary-schema.md`. The block will be written into the plan header by `/brains:map` at phase-2 step 11; stash it alongside the research document output so phase 2 can embed it verbatim (path: `docs/research/YYYY-MM-DD-<slug>-research-summary.yaml`, or inline in conversation state passed to the chained skill). All five fields (`libraries-and-versions`, `deprecated-apis-to-avoid`, `codebase-patterns`, `prior-art`, `constraints`) MUST be present. The full research document remains authoritative and on disk for drill-down.

### 3. Question generation (mode-dependent)

You are aiming for generally 2-4 questions, each with explicit pros and cons, informed by the user's prompt and the research document from step 2. Each question should frame a real architectural choice — not a preference poll. Write pros and cons that would survive adversarial review.

Mode-specific procedure:

- **`--single`:** spawn a single subagent and instruct it to generate the 2-4 question set with pros and cons. Use its output directly.
- **`--parallel` (default):** spawn the subagent as in `--single` and concurrently invoke the star-chamber to produce its own candidate question set. Follow the parallel-mode protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`. After both return, merge the two sets: de-duplicate semantically equivalent questions (not just string matches), keep the strongest framing and pro/con pairing for each, and drop questions that are strictly weaker variants.
- **`--debate`:** spawn the subagent and star-chamber and run them across `--rounds N` (default 2) or until convergence, following the debate protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`. Each round, both sides see the other's questions and critique / revise. Stop early if both sides converge on the same set.

After merging (parallel) or converging (debate), proceed directly to the questionnaire in step 5 — do NOT present the question set for pre-approval. The per-question adaptive flow in step 5 provides course-correction; a separate approval gate is redundant by construction.

**Under `--grill`:** generate the seed set identically to non-grill mode (2–4 questions with pros and cons). Additionally, EVERY seed question MUST include a **recommended answer** with a one-sentence rationale. The seed set is the **first round** of grilling, not the full questionnaire — the 2–4 cap applies only to the seed; the questionnaire in step 5 may extend beyond it. Under `--grill --parallel` or `--grill --debate`, star-chamber consultation applies to the seed only; follow-up questions MUST be generated locally.

### 4. Offer visual companion (own message)

If any anticipated question would be clearer with a visual (layout comparison, state-machine mockup, component diagram, architecture diagram), offer the browser-based visual companion in its own message. See `$BRAINS_PATH/skills/brains/references/visual-companion.md` for the detailed guide. This is a per-question tool, not a mode — accept once, then decide per-question whether to use terminal or browser.

Offer prompt:
> "Some of what we're working on might be easier to explain if I can show it to you in a web browser. I can put together mockups, architecture diagrams, comparisons, and other visuals as we go. This feature is still new and can be token-intensive. Want to try it? (Requires opening a local URL)"

### 5. Interactive questionnaire

For each generated question:
1. Present the question with pros and cons.
2. Accept the user's answer.
3. Adapt the remaining question set based on new information.
4. If an answer (a) contradicts a research finding, (b) introduces a new architectural dimension, or (c) renders remaining questions interdependent in unforeseen ways: re-engage the star-chamber for question review; optionally spawn a fresh research subagent for the new dimension.

**Under `--grill`**, read `$BRAINS_PATH/skills/brains/references/grill-protocol.md` (lazy-on-demand) and apply the full grill questionnaire policy. Per-turn behavior:

- **Convergence check (MUST):** after each user answer, evaluate against the 5-signal operational definition of "new architectural dimension" (signals a–e in grill-protocol.md §1). Track consecutive no-new-dimension answers; two consecutive MUST trigger the convergence proceed-prompt.
- **Codebase exploration (SHOULD):** before generating a follow-up, perform up to 1 Grep or Read call to either answer the candidate question from code or surface a contradiction with the user's stated answer. MUST continue on read failure without aborting.
- **Fuzzy-term sharpening (SHOULD):** when the user uses an overloaded term, propose a canonical term and ask for confirmation in the next turn before incorporating it into the architecture.
- **Edge-case probing (SHOULD):** when a domain relationship or data flow is discussed, probe with one concrete edge-case scenario before closing the topic.
- **Contradiction surfacing (MUST):** when a codebase read reveals that the user's stated claim contradicts the actual code, surface the contradiction as the next grill question.

**Termination and batching (under `--grill`):**

- **Upfront message (MUST):** before presenting the first grill question, emit: _"Grilling targets 8 total question turns. If more questions arise, I'll batch them to stay within budget. After 8 turns I'll check in to see if we should proceed or keep going."_
- **8-turn budget:** the system targets ≤ 8 total question turns. As long as anticipated total ≤ 8, ask one question per turn.
- **Auto-batching (MUST when anticipated total > 8):** compute `batch_size = ceil(remaining / max(1, 8 - turns_used))`, clamped to `[2, 5]`. Each batched question MUST still include a recommended answer.
- **Mandatory check-in (MUST):** once 8 turns are consumed and more than 1 question remains, emit: _"We've covered 8 question turns. Ready to proceed, or keep grilling? [y/N]"_ If the user responds `y`/`yes`/`proceed`, begin step 6. If `n`/`no`/`keep grilling`, reset the no-new-dimension streak and continue in batched mode.
- **"1 turn left" exception (MUST):** if exactly 1 question remains when the turn-8 check-in would fire, ask that final question directly without the check-in prompt (the round-trip cost exceeds the cost of one more turn).
- **Seed exclusion (MUST NOT):** do not batch the seed set under `--grill --parallel` or `--grill --debate`; batching applies only to follow-up questions.

### 6. Architecture synthesis

Produce the full architecture with up-to-date standards. Version specification is SHOULD-level — prefer MAJOR.MINOR for semver libraries; use the library's native scheme for non-semver.

### 7. Architecture review (mode-dependent)

The review pass sits between synthesis and ADR generation. What happens here depends on the mode:

- **`--single`:** skip review entirely. Present the synthesized architecture directly to the user for the gate in step 9.
- **`--parallel` (default):** invoke the star-chamber to review the synthesized architecture, following the parallel-mode protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`. Collect feedback across categories (soundness, version choices, missing concerns, testability). Present the feedback to the user alongside your recommendation and integrate accepted items into the architecture before writing the ADR.
- **`--debate`:** run the star-chamber in debate mode across `--rounds N` (default 2) or until convergence, following the debate protocol in `$BRAINS_PATH/references/multi-llm-protocol.md`. Providers see each other's critiques and respond. Integrate the converged feedback (with user approval on contested items) before writing the ADR.

### 8. ADR generation

Produce one or more ADRs in `docs/adr/` following the template and conventions in `$BRAINS_PATH/skills/brains/references/adr-template.md`. Filename format: `YYYY-MM-DD-NNN-<title>.md` (globally sequential NNN).

**Auto-trigger diagrams** (after each ADR is written, unless `--no-diagram` was passed):

Evaluate the synthesized architecture against these heuristics in priority order:

1. `state` — ≥1 state machine or lifecycle with ≥2 transitions.
2. `er` — ≥2 entities with ≥1 relationship between them.
3. `flowchart` — ≥3 components with ≥2 relationships.
4. `c4` — system context or container view with named actors.
5. `sequence` — ≥2 named participants AND ≥3 ordered message exchanges (request/response, call/return, publish/subscribe, or sequential event steps) between them. Linear event narratives without named senders and receivers fall through to `flowchart`.

Priority: `state > ER > flowchart > C4 > sequence`. When `--max-diagrams 1` (default), dispatch only the highest-priority match. When `--max-diagrams N > 1`, dispatch one diagram per firing heuristic in priority order up to N. When `--diagram <type>` was passed, force exactly that type regardless of heuristics.

Each dispatched diagram: invoke `/brains:diagram` as a sub-skill with `--type <type>` and the ADR filename stem as context. At most one diagram per type per ADR.

### 9. User gate

**Visual companion push (before terminal prompt):** If the companion is active, write the ADR gate view to a new file in `screen_dir` NOW — before presenting the terminal gate prompt. Use `renderADRView()` as documented in `$BRAINS_PATH/skills/brains/references/visual-companion.md`:

```html
<script>
  window.renderADRView([
    { filename: '<adr-filename>', status: '<status>', body: '<full ADR body>' }
  ]);
</script>
```

The companion view MUST remain visible while the user evaluates options. Do NOT push a waiting screen until AFTER the user responds to the gate.

Present the ADR(s) to the user. Gate behavior depends on the resolved values of `--autopilot` and `--accept-adrs` (per ADR-005 reqs 33-34):

- **`--autopilot` AND `--accept-adrs` both true:** do NOT prompt — auto-select option 2 and proceed.
- **`--autopilot` true, `--accept-adrs` false (default):** present the ADR gate normally and await user input. Autopilot semantics resume only AFTER the user accepts (option 1, 2, or 6). This preserves human-in-the-loop on architectural commitments.
- **Neither flag (interactive default):** present the gate normally.

When prompting, ask the user to choose exactly one of:

> **`--grill --autopilot --accept-adrs` handoff:** when all three flags are present, the grill questionnaire (steps 3–5) runs to full convergence in phase 1 — interactive questioning is not skipped. After the phase-1 gate, autopilot semantics take over: option 2 is auto-selected and the skill chains into `/brains:map --autopilot`. The intent is "interview me thoroughly, then go hands-off." Without `--accept-adrs`, the ADR gate is still presented after grilling. To opt out of the downstream autopilot while keeping grilling, use `--grill` without `--autopilot`.

1. **Accept ADR(s), push to origin, and chain into `/brains:map`** (planning mode) with the inherited mode flag.
2. **Accept ADR(s), push to origin, and chain into `/brains:map --autopilot`** (hands-off planning + implementation) with the inherited mode flag.
3. **Accept ADR(s), push to origin, and stop.** No further phases run.
4. **Reject ADR(s) and stop.** Record the rejection reason (free-form); do not loop.
5. **Provide fixes or alternate instructions.** User writes concrete edits or new guidance. Treat the text as input to a re-run of step 6 (architecture synthesis) and step 7 (architecture review) with the current ADR draft + user guidance appended to context. Re-present at this gate when the revised ADR is ready.
6. **(Conditional) Accept ADR(s), push to origin, and skip to inline implementation** — available ONLY when the synthesized architecture flags all three: no new external dependencies, no new external services, single-component change. Offer this option only when all three flags are met. When accepted, the CURRENT session proceeds to implement the ADR inline without invoking `/brains:map` or `/brains:implement`. Use beads + TDD to track and execute tasks directly; spawn nurture + secure subagents at the end. Autopilot NEVER auto-selects this option.

#### Handling options 1-3: branch, commit, push, draft PR, link surfacing

Before chaining (options 1/2) or stopping (option 3), perform the following sub-steps in order. Each sub-step is a separate concern; do not collapse them.

##### (a) Topic-branch offer (per ADR-005 req 36)

ADR commits MUST land on a topic branch, not on a base branch. Hoisted from `/brains:map` step 3 so the ADR review PR has a clean home.

```bash
CURRENT_BRANCH=$(git branch --show-current)
# Base branches: main, master, develop (or settings.local.json key brains.baseBranches)
```

- **If `CURRENT_BRANCH` is a base branch (`main`/`master`/`develop`):**
  - **Interactive:** prompt *"Create topic branch `brains/<slug>` and switch to it before committing the ADR? [Y/n]"*. On yes/default: `git checkout -b brains/<slug>` and emit a one-line status (`"Switched to new branch brains/<slug>"`). On no: continue on the current branch with a one-line warning that the ADR commit will land on `<base>`.
  - **`--autopilot`:** auto-create without prompting — `git checkout -b brains/<slug>` — and emit a one-line status update.
- **Otherwise** (already on a non-base branch): use the current branch silently — no prompt, no status line.

##### (b) Commit and push the ADR

Commit the newly produced ADR files (and the research document from step 2 if not already committed) and push to origin. Use conventional-commit prefix `docs(adr):`.

```bash
# Stage and commit (files listed explicitly — never `git add .`)
git add docs/adr/YYYY-MM-DD-NNN-<slug>.md
[[ -f docs/research/YYYY-MM-DD-<slug>-research.md ]] && git add docs/research/YYYY-MM-DD-<slug>-research.md
git commit -m "docs(adr): add ADR-NNN <title>"

# Push — set upstream if the branch has none
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git push
else
  git push -u origin "$(git branch --show-current)"
fi
```

If the push fails (auth, protected branch, network), surface the error to the user. Do NOT bypass hooks or force-push. Offer: (a) retry after the user resolves the issue, (b) skip push and continue locally (options 1/2 still chain; option 3 still stops), (c) abort.

##### (c) Auto-create draft PR (per ADR-005 req 37)

After a successful push, IF `command -v gh` succeeds AND `git remote get-url origin` contains the substring `github.com`, auto-create a draft PR per ADR. Build `<ADR title>` from the ADR file's first H1 line (e.g., `ADR-NNN: <Title>`).

```bash
if command -v gh >/dev/null 2>&1 && git remote get-url origin 2>/dev/null | grep -q github.com; then
  for ADR in <list of newly created ADR paths>; do
    ADR_TITLE=$(sed -n 's/^# *//p' "$ADR" | head -n1)
    PR_OUTPUT=$(gh pr create --draft --title "$ADR_TITLE" --body-file "$ADR" 2>&1) || true
    if echo "$PR_OUTPUT" | grep -q 'already exists'; then
      echo "Draft PR already exists for branch; skipping creation"
    else
      # Capture the URL from the last line of stdout (gh prints it on success)
      PR_URL=$(echo "$PR_OUTPUT" | tail -n1)
    fi
  done
fi
```

Skip silently when `gh` is missing or the origin is not a GitHub remote. Capture `PR_URL` for sub-step (d).

##### (d) Surface ADR + PR links (per ADR-005 req 37b)

BEFORE the gate options menu (the actual prompt the user types `1`/`2`/etc into) but AFTER commit+push and the optional draft-PR creation, surface clickable GitHub links. URL format:

```
https://<host>/<owner>/<repo>/blob/<branch>/<adr-path>
```

Derive `<host>/<owner>/<repo>` from `git remote get-url origin` — handle BOTH forms:
- `https://github.com/<owner>/<repo>(.git)?` → host=`github.com`, owner+repo as-is
- `git@github.com:<owner>/<repo>(.git)?` → host=`github.com`, owner+repo from after the colon

Strip a trailing `.git` if present. Use `<branch>` from `git branch --show-current` (the topic branch from sub-step (a)).

Format as a labeled list:

```
Review ADRs:
- https://github.com/<owner>/<repo>/blob/brains/<slug>/docs/adr/YYYY-MM-DD-NNN-<slug>.md
[- https://github.com/<owner>/<repo>/blob/brains/<slug>/docs/adr/YYYY-MM-DD-NNN-<slug-2>.md ...]

Draft PR:
- <PR_URL captured in sub-step (c)>
```

Omit the `Draft PR:` block when no PR was created (no `gh`, no GitHub remote, or `already exists` was logged). Skip the entire links block silently when no GitHub remote exists.

#### Handling option 4: terminal rejection

Write the rejection reason to `docs/plans/YYYY-MM-DD-<slug>-rejected.md` (single-paragraph note), then stop. Do not commit.

#### Handling option 5: user-provided fixes

Capture the user's text verbatim. Append to context as `User-provided fixes:\n<text>` and re-run step 6 (synthesis) then step 7 (review), producing a revised ADR. Re-present the revised ADR at this gate.

**Diagram regeneration after option 5:** After the revised ADR is produced, enumerate `docs/adr/diagrams/` for files matching the current ADR's stem — check each type explicitly (not a wildcard glob): `<adr-stem>-state.mmd`, `<adr-stem>-flowchart.mmd`, `<adr-stem>-er.mmd`, `<adr-stem>-sequence.mmd` (Mermaid types) and `<adr-stem>-c4.dsl` (Structurizr). For each found: read the first line. If it exactly matches the auto-trigger marker for its language, re-invoke `/brains:diagram` to regenerate from the updated architecture (ordered overwrite: write source first, then `.svg`; on `.svg` write failure due to parse/generation error, unlink the stale `.svg`). If the first line does not match, skip and log one line: `skipping user-authored diagram: <filename>`.

#### Handling option 6: skip to inline implementation

Commit and push the ADR(s) as in options 1–3. Then implement the ADR inline in the current session:

1. Create beads tasks from the ADR requirements (one task per MUST/SHOULD requirement, or aggregate related requirements into one task when cohesive). Label tasks with `brains:topic:<slug>` and `brains:phase-1`.
2. Execute tasks directly using TDD where applicable. Do NOT spawn a teammate Claude Code instance.
3. At the end, invoke `/brains:nurture --scope phase-1` and `/brains:secure --scope phase-1` as subagents for review and fixes.
4. Commit changes with conventional-commit messages; do not push until nurture and secure pass.

Eligibility is author-gated: surface the option only when the architecture flags all three prerequisites (no new external deps, no new external services, single-component change). If the user selects option 6 despite missing a prerequisite (e.g., by typing "6" explicitly), emit a warning and confirm once before proceeding.

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
- **`$BRAINS_PATH/skills/brains/references/grill-protocol.md`** — `--grill` operational rules (lazy-on-demand; load only when `--grill` is active)
