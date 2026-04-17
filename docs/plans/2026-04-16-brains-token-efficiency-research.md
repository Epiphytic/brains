# BRAINS Token Efficiency Research

**Date:** 2026-04-16
**Status:** Research only — no decisions made
**Scope:** v0.2.1 codebase (plugin.json version), files as of commit 5a717bb

---

## 1. Inventory: File Sizes and Load Patterns

### Phase Skill Files (loaded once per invocation, body read in full by the executing model)

| File | Lines | Est. tokens | Load pattern |
|---|---|---|---|
| `skills/setup/SKILL.md` | 341 | ~4,100 | Once per `/brains:setup` invocation |
| `skills/implement/SKILL.md` | 224 | ~2,700 | Once by master; **also fully re-read by every spawned teammate** |
| `skills/secure/SKILL.md` | 223 | ~2,680 | Once per secure subagent invocation (per plan-phase) |
| `skills/nurture/SKILL.md` | 198 | ~2,380 | Once per nurture subagent invocation (per plan-phase) |
| `skills/brains/SKILL.md` | 193 | ~2,320 | Once per `/brains:brains` invocation |
| `skills/map/SKILL.md` | 146 | ~1,750 | Once per `/brains:map` invocation |
| `skills/suggest/SKILL.md` | 64 | ~770 | Auto-triggered, advisory only |

Token estimate: ~12 tokens/line for prose-and-table-heavy markdown. Verified against files read.

### Reference Files (read on-demand via Read tool during execution)

| File | Lines | Est. tokens | When read |
|---|---|---|---|
| `references/multi-llm-protocol.md` | 209 | ~2,500 | Every `--parallel` or `--debate` phase (1, 2, 3 master, 3 nurture×N, 3 secure×N) |
| `references/beads-integration.md` | 143 | ~1,720 | Phases 2 and 3 (task creation, queries) |
| `references/failure-recovery.md` | 114 | ~1,370 | Phase 3 master + every teammate (including happy-path runs) |
| `references/teammate-protocol.md` | 101 | ~1,210 | Phase 3 master spawn + teammate T6 section |
| `skills/brains/references/visual-companion.md` | 157 | ~1,885 | Phase 1 only, optional (offered unconditionally) |
| `skills/map/references/plan-format.md` | 56 | ~670 | Phase 2 plan generation subagent |
| `skills/setup/references/settings-format.md` | ~80 | ~960 | Setup only |

### Generated Artifacts Re-read During Pipeline

| Artifact | Typical size | Re-read by |
|---|---|---|
| `docs/plans/*-research.md` | 200–600 lines | Phase 2 freshness check; teammates (grooming input via plan header) |
| `docs/plans/*-map.md` | 50–200 lines | Phase 3 master load; every teammate T1; `--resume` logic |
| `docs/adr/*.md` | 50–120 lines/ADR | Every teammate initial prompt; grooming subagent; nurture/secure subagents |
| `docs/plans/.state/*-marker.json` | ~8 lines | Polled every 15s by master (tiny per-read, negligible) |
| `docs/plans/*-phase-N-nurture.md` | 50–150 lines | Written by nurture; not re-read by pipeline in v0.2.1 |
| Design doc (`2026-04-14-*-design.md`) | 564 lines | Not read at runtime; human reference only |
| Implementation plan (`2026-04-15-*-plan.md`) | 2,124 lines | Not read at runtime; human reference only |

---

## 2. Token Cost Centers, Ordered by Estimated Impact

### Cost Center 1: Star-Chamber Context Assembly (per invocation, not cached)

**Impact: HIGH**

`references/multi-llm-protocol.md:56-60` specifies that every star-chamber call writes a `$SC_TMPDIR/context.txt` from scratch, including:
- `ARCHITECTURE.md` if it exists
- `.claude/rules/*.md` files
- `git diff HEAD~3 --stat`
- Skill-specific payload (research doc, ADR draft, plan, changed file contents)

Each `context.txt` can reach 2,000–8,000 tokens depending on project size. In a full `--parallel --autopilot` run with 3 plan-phases, star-chamber is invoked at minimum: phase-1 question gen (1×), phase-1 architecture review (1×), phase-2 plan review (1×), phase-3 nurture review (3×), phase-3 secure review (3×) = **9 context assemblies with no reuse between calls**. In `--debate` mode with 2 rounds each, this rises to ~18 assemblies.

### Cost Center 2: Reference Document Re-reads Across Phases

**Impact: HIGH**

`multi-llm-protocol.md` (2,500 tok) is referenced in `brains`, `map`, `implement`, `nurture`, and `secure` SKILL.md files and must be read during any `--parallel` or `--debate` execution. In a full `--parallel` run it is read at minimum 5 times (phases 1, 2, 3 master, nurture×1, secure×1 minimum) and up to 9 times in a 3-phase run. It is a stable file that does not change between reads within a session.

`failure-recovery.md` is flagged as "entire file" per `implement/SKILL.md:213` ("Follow `$BRAINS_PATH/references/failure-recovery.md` — entire file"). This is read at master initialization and by every teammate, regardless of whether any failures occur. For a 3-phase happy-path run: 1 master read + 3 teammate reads = 4 reads × 1,370 tokens = **5,480 tokens consumed for content that is only needed on failure**.

### Cost Center 3: Teammate Initial Context Load (Multiplied by Phase Count)

**Impact: HIGH**

Each of the N plan-phase teammates reads these files at spawn:

- `implement/SKILL.md` (full, 2,700 tok) — includes master-side steps 1–7 (lines 48–160, ~115 lines, ~1,380 tok) that teammates never execute; teammate-relevant content starts at line 163
- `failure-recovery.md` (1,370 tok) — eager load regardless of failures
- `references/teammate-protocol.md` (1,210 tok) — for T6 completion marker
- `references/beads-integration.md` (1,720 tok) — for T2/T3 task queries
- The plan document (50–200 lines, 600–2,400 tok)
- ADR(s) (50–120 lines each, 600–1,440 tok per ADR)
- `multi-llm-protocol.md` (2,500 tok) — if mode is `--parallel` or `--debate`

Per-teammate structural overhead: **~7,000–12,000 tokens** (excluding implementation execution). For a 3-phase run: **21,000–36,000 tokens in structural load alone**, before any grooming or coding.

### Cost Center 4: Research Document Re-read

**Impact: MEDIUM — size is topic-dependent**

The research document is written in phase 1 (`docs/plans/*-research.md`) and re-read in:
1. Phase 2 at `map/SKILL.md:69-73` (freshness decision + content for plan generation)
2. Teammate grooming in phase 3 (passed via the plan document's Research header field, causing teammates to read it)

For a substantive topic, research documents are 200–600 lines (2,400–7,200 tokens). This document contains the full prose of the research subagent's exploration — library versions, deprecated APIs, codebase patterns, prior art — much of which was consumed during phase 1 synthesis and need not be retransmitted verbatim.

### Cost Center 5: Duplicate Boilerplate Across SKILL.md Files

**Impact: MEDIUM — structural repetition across 5–6 files**

Repeated near-identically in multiple skills:

1. **`BRAINS_PATH` setup block** (3 lines): present in `brains`, `map`, `implement`, `nurture`, `secure`, `setup` = 6 copies.
2. **Mode behavior table + introductory prose** (~8 lines each): present in all five phase skills with only minor wording differences (`implement/SKILL.md:19-31`, `nurture/SKILL.md:18-28`, `secure/SKILL.md:18-26`, `brains/SKILL.md:19-25`, `map/SKILL.md:19-27`).
3. **"Additional Resources" footer** (3–5 lines): present in `brains`, `map`, `implement`, `nurture`, `secure`.
4. **ADR markdown template** (`brains/SKILL.md:96-138`, 42 lines, ~500 tok): defined inline rather than as a sub-reference.
5. **Partial restatement of `multi-llm-protocol.md` mode table**: each phase skill contains a short version of the mode table that is not in `multi-llm-protocol.md` proper.

Total structural duplication across skills: approximately 1,500–2,000 tokens of content that appears 5–6 times.

### Cost Center 6: Phase-1 Parallel Question Generation Double-Pass

**Impact: MEDIUM**

`brains/SKILL.md:60`: in `--parallel` mode both a local subagent and the star-chamber independently generate candidate question sets, which are then merged. This doubles the question-generation compute. The merge pass holds both sets in context (~400–1,000 tokens of candidates). The star-chamber call requires context assembly (see Cost Center 1), including the research document if it exists.

This is one of the core quality mechanisms (it surfaces questions the local model wouldn't generate), so the cost has explicit rationale in `why-brains.md`. It is noted here as a measurable cost, not a candidate for removal.

### Cost Center 7: Debate-Mode Round JSON Volume

**Impact: MEDIUM in debate mode, zero in parallel/single**

Each debate round writes a `$SC_TMPDIR/round-N.json` containing full verbatim provider responses. For a 3-provider configuration and a 500-word question, a single round JSON may contain 3,000–6,000 tokens of provider text that must be parsed with the Read tool before synthesis. With 2 rounds per debate point, a full `--debate` run with 3 debate points (questions, architecture review, plan review) produces 6 JSON files totaling potentially 18,000–36,000 tokens of intermediate content — much of which is discarded after synthesis.

### Cost Center 8: Plan Document Multiple Reads

**Impact: LOW-MEDIUM**

The map document (`docs/plans/*-map.md`) is read by:
- Phase 3 master at startup (`implement/SKILL.md:54`)
- Every teammate at T1
- `--resume` logic

For a 3-phase run: 4 reads. At ~80 lines (~960 tok) per read, this is ~3,840 tokens total. The plan document is small enough that this is not a bottleneck, but it is the most frequently re-read structural file in phase 3.

---

## 3. Specific Questions Answered

### What context is re-read across phases that could be summarized or cached?

`multi-llm-protocol.md` is the prime candidate — 2,500 stable tokens read 5–9 times per run. The research document is the second: full prose re-read in phase 2 and teammate grooming where a structured summary would suffice. The `failure-recovery.md` state machine is read by every teammate including happy-path runs where it is never needed.

### Which references are loaded eagerly that could be moved to on-demand?

`failure-recovery.md` (`implement/SKILL.md:213` instructs "entire file" at teammate init). `visual-companion.md` is referenced at `brains/SKILL.md:67` with a pointer that may cause eager loading even before the user accepts the offer.

### Are there duplicated instructions across phase SKILL.md files?

Yes. Five patterns identified: `BRAINS_PATH` block (6 copies), mode table intro prose (5 copies), Additional Resources footer (5 copies), inline ADR template (duplicated from the design document), and abbreviated multi-llm mode table (5 copies).

### Does the star-chamber context include unnecessary material?

`multi-llm-protocol.md:195-196` includes `.claude/rules/*.md` and `git diff HEAD~3 --stat` in every context assembly. The `--stat` diff is low-signal noise for design-question calls (phase 1, phase 2) where no implementation has occurred. Rules files may contain project-level CI and commit-convention instructions that are irrelevant to external LLMs evaluating architecture.

### Do teammate spawns replicate the parent's full skill content or only a pointer?

Full skill content. `implement/SKILL.md` (224 lines, ~2,700 tok) is loaded entirely by each teammate. The master-side flow section (steps 1–7, lines 48–160, ~1,380 tok) is content that teammates never execute. The teammate-relevant section begins at "Process (Teammate-Side)" at line 163.

### Are debate-mode round artifacts and synthesis text larger than they need to be?

The synthesis format (`multi-llm-protocol.md:120-135`) is compact and necessary (~200–400 tokens per synthesis). The round-N JSON files containing raw provider responses are the larger cost: 3,000–6,000 tokens per round for a 3-provider call, most of which is discarded after synthesis.

### Approximate token cost of a full `--autopilot --parallel` run end-to-end?

For a medium-complexity topic (1 ADR, 3 plan-phases, 5 tasks/phase, 2 providers), structural overhead only:

| Stage | Tokens |
|---|---|
| Phase 1: skill load + references (multi-llm-protocol.md) | ~4,820 |
| Phase 1: research subagent (writes ~400-line doc) | ~8,000 execution context |
| Phase 1: parallel question gen (subagent + star-chamber context ~3,000 each) | ~8,000 |
| Phase 1: architecture review star-chamber (context + response per provider) | ~6,000–12,000 |
| Phase 1: ADR generation output (~80 lines) | ~960 |
| Phase 2: skill + multi-llm-protocol.md + beads-integration.md | ~5,970 |
| Phase 2: plan generation subagent | ~4,000 |
| Phase 2: star-chamber plan review | ~4,000–8,000 |
| Phase 3: master skill load | ~2,700 |
| Phase 3: 3 teammates × (skill + 4 references + ADR + plan) | ~21,000–36,000 |
| Phase 3: 3 teammates × grooming subagent (per task research) | ~9,000–18,000 |
| Phase 3: 3× nurture (skill + multi-llm + star-chamber review) | ~9,000 |
| Phase 3: 3× secure (same) | ~9,000 |
| **Structural overhead subtotal** | **~91,000–128,000 tokens** |
| Implementation subagent execution (actual coding) | task-dependent (typically 2×–5× structural overhead) |

These numbers are estimates based on line counts and observed markdown tokenization rates (~12 tokens/line). Implementation tokens vary enormously by codebase size and task complexity.

---

## 4. Prior Art: How Similar Pipelines Handle Context Compression

**LangGraph agent pipelines** — pass a shared state dict between graph nodes rather than re-reading source files. Between stages, a summarization node compresses accumulated output into structured fields. Applicable to BRAINS: the research document could be summarized into 5 structured fields before passing to phase 2 and teammates.

**OpenAI Assistants API thread model** — threads persist message history; the API handles automatic windowing/summarization. The pattern of "maintain a rolling summary rather than full history" applies to how debate-round artifacts are managed — only the synthesis, not the round JSON, needs to persist.

**Cursor/Cline `.rules` and `CLAUDE.md` session loading** — project rules are loaded once at session start and cached for the duration. BRAINS skill bodies are loaded per-invocation; there is no equivalent session-level cache. If the plugin architecture supported a "shared context loaded once per session" hook, reference files like `multi-llm-protocol.md` could benefit.

**Anthropic prompt caching** — the Claude API supports `cache_control: ephemeral` prefix blocks for large stable inputs, amortizing cost over multiple calls. Not directly applicable to the Claude Code plugin model (which does not expose prompt-caching control to plugin authors) but relevant as a future direction if plugin invocation semantics change.

---

## 5. Candidate Reduction Strategies

### Strategy A: Teammate-Side Skill Split (HIGH IMPACT, LOW RISK)

Split `implement/SKILL.md` into a master section (steps 1–7 + autopilot) and a teammate section (steps T1–T6 + failure-flow summary). Teammates receive only the teammate section (~61 lines, ~730 tok) instead of the full file (~2,700 tok). The `references/teammate-protocol.md` "Initial Prompt Template" section is already the natural anchor for delivering this.

Saves: ~1,380 tok × N teammates per run (N = plan-phase count). For 3 phases: ~4,140 tok.

Tradeoff: adds a second file to maintain; failure to keep them in sync creates inconsistency.

### Strategy B: Lazy Load `failure-recovery.md` (MEDIUM IMPACT, LOW RISK)

`implement/SKILL.md:213` currently says "Follow `$BRAINS_PATH/references/failure-recovery.md` — entire file." Replace with: "On first task failure, read `$BRAINS_PATH/references/failure-recovery.md` in full and follow it. Key points: [current key-points summary]." The key-points summary (4 bullet points already present at lines 214–217) provides sufficient guidance for the happy path.

Saves: ~1,370 tok × (1 master + N teammates) per happy-path run. For 3 phases: ~5,480 tok.

Tradeoff: model must remember to read the file at failure time. Risk is low — failure events are salient; the model is unlikely to miss the instruction.

### Strategy C: Research Document Summary Pass (MEDIUM IMPACT, MEDIUM RISK)

After the research subagent writes `docs/plans/*-research.md`, add a step: append a 20-line structured summary block (libraries, deprecated APIs, patterns, prior art, constraints) to the plan document header. Phase 2 and teammates use the summary; the full document remains on disk for humans. The plan header already has a `Research:` field pointing to the file; this adds a `Research-Summary:` inline block.

Saves: (research doc size - 20 lines) × (N reads by teammates + 1 read by phase 2). For a 400-line doc and 3 teammates: ~(400-20) × 4 × 12 = ~18,240 tok.

Tradeoff: summarization may lose a nuance. The summary pass itself costs ~1,000–2,000 tokens. Net positive for docs > ~100 lines.

### Strategy D: Compact Protocol Inline + Full File on Demand (MEDIUM IMPACT, MEDIUM EFFORT)

Embed a compact inline version of the multi-llm protocol (mode table + invocation commands, ~25 lines, ~300 tok) in each phase skill where it is currently referenced. Load the full `multi-llm-protocol.md` only when the model hits an edge case (debate mode round synthesis, error handling). Most runs only need the parallel-mode happy path.

Saves: (2,500 - 300) tok × (N reads - 1) per run. For 5 reads per full parallel run: ~8,800 tok.

Tradeoff: compact inline version and full reference must be kept in sync. Adds maintenance burden. The full file is already reasonably compact at 209 lines.

### Strategy E: Scope Star-Chamber Context to Call Type (LOW IMPACT, LOW RISK)

In `multi-llm-protocol.md:196`, make `git diff HEAD~3 --stat` conditional: include only for code-review calls (`star-chamber review`), not for design-question calls (`star-chamber ask`). Add a note that `.claude/rules/*.md` files should be excluded unless they contain architectural constraints (user-configurable via `settings.local.json`).

Saves: ~200–800 tok per design-question call × N calls (3–9 per run) = ~600–7,200 tok.

Tradeoff: minimal — `--stat` output is compact and the savings are modest. Highest value for projects with large rules files.

### Strategy F: ADR Template as Sub-reference (LOW IMPACT, LOW RISK)

Move `brains/SKILL.md:96-138` (42 lines, ~500 tok) to `skills/brains/references/adr-template.md`. The phase-1 skill references it with a single line.

Saves: ~500 tok per phase-1 run (one-time, since ADR generation happens once per pipeline).

Tradeoff: adds a file; marginal benefit. Primarily worthwhile as hygiene alongside Strategy A if splitting skill files.

---

## 6. Summary Table: Token Cost Hierarchy

| Rank | Cost Center | Est. tokens/full run | Best strategy |
|---|---|---|---|
| 1 | Star-chamber context assembly (per call, not cached) | 15,000–40,000 | Strategy E (scope), D (compact protocol) |
| 2 | Reference re-reads (`multi-llm-protocol.md` ×5–9) | 12,500–22,500 | Strategy D |
| 3 | Teammate full skill re-read including master-side section (×N) | 4,140 (3 phases) | Strategy A |
| 4 | `failure-recovery.md` eager load on happy path (×N+1) | 5,480 (3 phases) | Strategy B |
| 5 | Research document re-read in phase 2 + grooming (size-variable) | 2,400–28,800 | Strategy C |
| 6 | Debate-mode round JSON parsing (provider-side content) | 0–36,000 | Limited — provider API constraint |
| 7 | Duplicate boilerplate across SKILL.md files | 1,500–2,000 total | Strategy F + cleanup |
| 8 | Plan document re-reads (×4 in 3-phase run) | ~3,840 | Not a priority |

**Top three strategies by ROI:**
1. Strategy C (research doc summary pass) — saves up to 28,800 tok on large research docs at cost of a simple summarization step
2. Strategy D (compact protocol inline) — saves ~8,800 tok per full parallel run at cost of maintaining two versions of protocol content
3. Strategies A + B together (teammate skill split + lazy failure-recovery) — saves ~9,620 tok per 3-phase happy-path run at low implementation risk

No strategies in this list require removing any quality-producing behavior. Multi-LLM review, interactive gates, systematic phases, beads tracking, ADRs, plan-phase scoping, and autopilot are all orthogonal to these structural savings.

---

## 7. Key File References

- `skills/brains/SKILL.md` — phase 1, 193 lines
- `skills/map/SKILL.md` — phase 2, 146 lines
- `skills/implement/SKILL.md` — phase 3 master+teammate, 224 lines; teammate section begins line 163
- `skills/nurture/SKILL.md` — 198 lines; reads `multi-llm-protocol.md` in parallel/debate mode
- `skills/secure/SKILL.md` — 223 lines; same
- `references/multi-llm-protocol.md` — 209 lines; most-read reference in pipeline; context assembly at lines 56-60, context-gathering standard at lines 193-197
- `references/failure-recovery.md` — 114 lines; loaded eagerly by implement skill at line 213
- `references/beads-integration.md` — 143 lines; task creation/queries
- `references/teammate-protocol.md` — 101 lines; spawn, sync, marker format
- `skills/brains/references/visual-companion.md` — 157 lines; loaded on offer at `brains/SKILL.md:67`
- `docs/why-brains.md` — design rationale explaining why each cost-producing mechanism exists
