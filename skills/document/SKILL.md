---
name: document
description: This skill should be used when the user asks to "document mode", "edit only docs", "just update the docs", "fast-path a doc change", or invokes "/brains:document". Canonical entry point for BRAINS document mode: an abbreviated spine for document-only changes that skips planning, teammate orchestration, nurture, and secure. Runs an eligibility gate, lightweight research, the full 2-4 question questionnaire, a slim ADR, inline document edits, direct star-chamber council review (replacing nurture+secure), and an inline commit. Supports --single, --parallel (default), and --debate modes for the review phase, plus --autopilot and --lean.
user-invocable: true
argument-hint: "[--single|--parallel|--debate] [--autopilot] [--lean] [--teammate-model <model>] [topic]"
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent, TaskCreate, TaskUpdate
---

# BRAINS Document Mode: Abbreviated Doc-Only Spine

Drive a document-only change through an eligibility gate, lightweight orientation, the full 2-4 question questionnaire, a slim ADR, inline edits, direct council review, and an inline commit. Document mode is the fast path for work that only edits documents (markdown and prose, not code): it skips `/brains:map`, teammate orchestration, `/brains:nurture`, and `/brains:secure`, reviewing the final document(s) directly with the star-chamber council instead. Default mode: `--parallel` with star-chamber review.

This skill is the **canonical** entry point for document mode. It is invocable directly (`/brains:document "<topic>"`) and is also the delegation target of the `/brains:brains` Step-1 guard (the `--document-mode` flag and auto-detected doc-only path); both routes run this same spine with identical eligibility, gating, and behavior.

`--teammate-model` is accepted only so the delegation from `/brains:brains` can forward its flag set verbatim; document mode never spawns teammate Claude Code instances (req 21), so the flag is inert here unless a future shared helper consumes it.

Set the plugin base path:

```bash
BRAINS_PATH="<base directory from header>/../.."
```

## Mode Behavior

Modes apply to the **review** phase (step 6). Eligibility, research, questionnaire, ADR, edits, and commit run identically across modes.

| Mode | Document review |
|---|---|
| `--single` | Local self-review only — explicitly lower-assurance; warn that council review is unavailable. |
| `--parallel` (default) | Final document(s) reviewed by the star-chamber council via `star-chamber review`. |
| `--debate` | Multi-round council deliberation over the final document(s). |

For `--parallel` and `--debate`, read and follow `$BRAINS_PATH/references/multi-llm-protocol.md`. Under `--lean`, read the compact excerpt at `$BRAINS_PATH/references/multi-llm-protocol-compact.md` instead; consult the full file only for debate-round synthesis or error handling.

## Hard Gate

Do NOT proceed past the eligibility gate (step 1) when the change contains non-document code files under a manual `--document-mode` override — hard-refuse and direct the user to the full `/brains:brains` pipeline.

## Process

### 1. Eligibility gate

Run the hybrid eligibility detection defined in `$BRAINS_PATH/skills/document/references/eligibility-detection.md`: deterministic bash classifies and counts the canonical changed set against the versioned document allow-list (`.md`, `.markdown`, `.mdx`, `.rst`, `.txt`, `.adoc`); the main LLM resolves in-scope target documents from the prompt (greenfield) and extracts/follows document links, confirming dependents with `test -f`.

A change is eligible only when it contains zero non-document files AND target documents ≤ 4 AND unique on-disk dependents ≤ 10. Target counts cover deliverables only — never BRAINS-generated artifacts (slim ADR, research, beads, diagrams).

Apply the mode-sensitive threshold behavior and asymmetric override exactly as the reference specifies: interactive **warn-and-ask** / autopilot **detect-then-fallback** with a loud notice for oversized-but-document-only scopes; **hard-refuse** when non-document code files are present (fenced/example code inside a document never triggers refusal). When detection routes to the full pipeline, stop this spine.

### 2. Lightweight research / orientation

Run a single lightweight research/orientation pass scoped to the target documents and the user's prompt. MAY skip when the scope is trivial. MUST NOT run the full multi-subagent research of `/brains:brains`.

If a useful orientation note is produced, write it to `docs/research/YYYY-MM-DD-<slug>-research.md` (committed to git). This note is a BRAINS-generated artifact and does not count toward the document ceiling.

### 3. Full interactive questionnaire (2-4 questions)

Run the full interactive 2-4 question questionnaire, with mode-dependent generation identical to `/brains:brains` steps 3 and 5. Do NOT reduce the question count below the standard 2-4 range — document edits routinely hide product or policy implications that the questionnaire surfaces.

Generation uses the same lightweight question-generation `Agent` subagent as `/brains:brains` — this is NOT a teammate Claude Code instance and does NOT constitute teammate orchestration (which req 21 forbids); it is the same in-session helper the core questionnaire already uses.

- **`--single`:** use a single question-generation subagent to produce the 2-4 question set with pros and cons; use its output directly.
- **`--parallel` (default):** run the question-generation subagent and concurrently invoke the star-chamber for its own candidate set, then merge and de-duplicate, per `$BRAINS_PATH/references/multi-llm-protocol.md`.
- **`--debate`:** run the subagent and star-chamber across rounds until convergence, per the debate protocol.

Present each question with pros and cons, accept the user's answer, and adapt the remaining set as new information arrives.

### 4. Slim ADR

Produce a **slim ADR** in `docs/adr/` following `$BRAINS_PATH/skills/document/references/slim-adr-template.md`, using the standard filename and globally-sequential-NNN convention (`YYYY-MM-DD-NNN-<title>.md`). Retain Context, Decision, Requirements (RFC 2119), and Consequences; omit Assumed Versions and Diagram. The slim ADR is a BRAINS-generated artifact and does not count toward the document ceiling.

### 5. Inline document edits

Edit the target documents inline in the current session. MUST NOT invoke `/brains:map`, spawn teammate Claude Code instances, or invoke `/brains:implement`. SHOULD track work with lightweight beads tasks labeled `brains:document:<slug>`.

After editing, re-run the **full** eligibility probe (per the reference §2–§6) against the now-changed working tree — including non-document-file detection, not just the document count — excluding only the artifacts this spine authored from the target-document count. If editing accidentally introduced a code file or pushed counts over the ceiling, react per the threshold/override rules before proceeding to review and commit.

### 6. Direct council review (replaces nurture + secure)

This step replaces the nurture and secure passes. MUST NOT invoke `/brains:nurture` or `/brains:secure`.

**`--parallel` / `--debate`:** review the final document(s) directly with the star-chamber council. Write a context file holding the original prompt plus main-LLM-curated supporting materials (research and the slim ADR).

First, partition the final documents by word count — a document **under 10,000 words** is passed to the council **in full**; a document **at or above 10,000 words** MUST instead be passed as a main-LLM-curated excerpt plus summary (NOT the full file):

```bash
wc -w <final doc path>
```

For each ≥ 10,000-word document, write its curated excerpt+summary to a review-input file (a BRAINS-generated artifact). Then build the review target list as: the under-10k document paths as-is, plus the curated excerpt+summary paths in place of each oversized document. Run, in ONE bash command:

```bash
SC_TMPDIR="<literal path>"; uvx star-chamber review --context-file "$SC_TMPDIR/context.txt" --format json <under-10k doc paths and curated excerpt+summary paths>
```

Parse the JSON, present the council review to the user, and integrate accepted findings into the source documents (not the excerpts).

**`--single`:** perform a local self-review of the documents in place of the council review. Treat it as explicitly **lower-assurance** and warn the user that council review is unavailable and that `--parallel` is recommended.

### 7. Inline commit and .gitignore

Own the git responsibilities normally held by nurture under `--scope phase-N` by following the shared procedure at `$BRAINS_PATH/references/commit-procedure.md`: run `git status --porcelain`, commit the document changes atomically with a conventional-commit `docs:`-prefixed message, and update `.gitignore` for any generated artifacts. Do NOT push (the user or a chained gate pushes).

## Output

- Slim ADR: `docs/adr/YYYY-MM-DD-NNN-<slug>.md`
- Optional orientation note: `docs/research/YYYY-MM-DD-<slug>-research.md`
- Edited target document(s), committed atomically with a `docs:`-prefixed message.

## Phase Transition

After the document-mode spine completes:

> "Document mode complete. Slim ADR written, document(s) edited and reviewed, changes committed.
>
> Next steps:
> - Push the commit when ready.
> - `/brains:brains` — run the full pipeline if scope grew beyond document-only work."

## Additional Resources

- **`$BRAINS_PATH/skills/document/references/eligibility-detection.md`** — hybrid detection: canonical changed set, allow-list, counting, link extraction, threshold and override behavior
- **`$BRAINS_PATH/skills/document/references/slim-adr-template.md`** — slim ADR template (Context, Decision, Requirements, Consequences)
- **`$BRAINS_PATH/references/commit-procedure.md`** — shared commit and `.gitignore` procedure
- **`$BRAINS_PATH/references/multi-llm-protocol.md`** — shared multi-LLM invocation protocol
