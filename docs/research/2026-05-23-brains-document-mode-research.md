# BRAINS Document Mode Research

**Date:** 2026-05-23
**Slug:** brains-document-mode
**Topic:** Map current BRAINS architecture to inform design of a "document mode" — a lightweight variant for document-only edits that bypasses or abbreviates the normal planning/phase machinery, replaces nurture+secure with direct star-chamber council review, and is auto-invoked or manually triggered via `--document-mode`.

---

## 1. Skill/Phase Structure

### 1.1 The Three-Phase Pipeline

The BRAINS pipeline is three phases chained sequentially:

- **Phase 1** — `/brains:brains` (`skills/brains/SKILL.md`): Interactive research, 2–4 question questionnaire, ADR production. Default mode: `--parallel`. Hard Gate: "Do NOT chain into `/brains:map` until an ADR has been written and the user has accepted it."
- **Phase 2** — `/brains:map` (`skills/map/SKILL.md`): Stub-level plan generation, beads task creation with `brains:`-prefixed labels, user approval gate. Default mode: `--parallel`.
- **Phase 3** — `/brains:implement` (`skills/implement/SKILL.md`): Master orchestrator spawns one teammate Claude Code instance per plan-phase. Default mode: `--parallel` (applies to nurture/secure inside teammates, not implementation itself).

Phases chain automatically via invocation strings built at each phase-transition block.

### 1.2 Teammate Flow (T1–T6)

Inside each plan-phase teammate (`skills/implement/teammate.md`):

- **T1**: Read inputs (ADR paths, plan path, phase label, mode, skills flag, model-hint defaults)
- **T1.1**: Skills probe (if `--skills` set)
- **T2**: Grooming subagent
- **T3**: Execution — iterate groomed tasks in dependency order, spawn subagents per task, two-strike-then-escalate flow
- **T4**: Nurture subagent — `invoke /brains:nurture --scope phase-<N>`
- **T5**: Secure subagent — blocked on T4; `invoke /brains:secure --scope phase-<N>`
- **T6**: Write completion marker JSON to `docs/plans/.state/`

### 1.3 User Gates

- **Phase 1 ADR gate** (step 9): Options 1–6. `--autopilot` alone does NOT skip; `--autopilot --accept-adrs` auto-selects option 2.
- **Phase 2 plan gate** (step 7): Reject / Accept / Accept-and-skip-teammate-spawn (conditional). `--autopilot` skips this gate.

### 1.4 Standalone/Shortcut Paths

- **Phase 1 option 6**: Inline implementation without map or implement — only when "no new external deps, no new external services, single-component change." Still invokes nurture + secure at the end.
- **Phase 2 Accept-and-skip-teammate-spawn**: Inline execution in current session. Still runs nurture + secure `--scope phase-1`.
- **`--bullets` serial-sweep mode**: Single plan-phase, 3–6 coarse tasks, inline execution. Still goes through map and implement.

### 1.5 Standalone Skill Invocations

`/brains:nurture` and `/brains:secure` are user-invocable standalone. Both default to `--scope all`.

---

## 2. Flag/Mode Plumbing

### 2.1 The 4-Layer Precedence Chain

Defined in ADR-005 reqs 18–19. For all boolean orthogonal flags (`--skills`, `--grill`, `--accept-adrs`, `--bullets`):

1. **Explicit CLI flag** — `--flag` / `--no-flag` wins.
2. **`.claude/brains.local.md` Flags table** — "Project Default" column (`true`/`false`). Empty rows fall through.
3. **`~/.config/brains/defaults.json` `flags` object** — `flags.<key>` boolean. Schema v0.3.0. Current keys: `skills`, `grill`, `bullets`, `accept_adrs`.
4. **Built-in default** — `false`.

`--no-*` MUST override a `true` config default (req 19). `/brains:implement` adds a fifth layer for `--skills`/`--accept-adrs` on `--resume`: the persisted plan header field is consulted between CLI flag and local settings.

### 2.2 Mode Flags (Mutually Exclusive)

`--single`, `--parallel`, `--debate`. Resolution: CLI → `.claude/brains.local.md` `## Default Modes` table → `defaults.json` `defaults.<skill>` → built-in per-skill default (brains/map/implement: `parallel`; nurture/secure: `single`).

### 2.3 Pattern for Adding a New Boolean Flag

A new boolean flag requires changes in ALL of:

| Location | Change |
|---|---|
| `skills/<skill>/SKILL.md` frontmatter `argument-hint` | Add `[--flag\|--no-flag]` |
| `skills/<skill>/SKILL.md` Step 1 | Add 4-layer resolution block |
| `skills/brains/SKILL.md` flag-propagation prose | Note propagation to map/implement |
| `~/.config/brains/defaults.json` `flags` schema | Add `<flag_key>: false` |
| `skills/setup/references/settings-format.md` | Document in `flags` object table |
| `.claude/brains.local.md` `## Flags` table | Add row |
| `skills/setup/SKILL.md` | Write the row when generating brains.local.md |
| `skills/map/references/plan-format.md` plan header | Add `Flag: <true\|false>` if persisted |
| `README.md` | Add to flags table and prose |
| `CHANGELOG.md` | Entry under next version |

Phase-1-only flags (`--grill`): explicitly do NOT propagate ("MUST NOT be forwarded to any chained skill"). Other orthogonal flags propagate via the invocation string at phase transition.

### 2.4 Propagation Mechanics

Propagation is text-based: each skill builds a literal invocation string at the phase-transition block (e.g. `Invoke /brains:map [mode] --lean`). Master MUST NOT pass resolved provider state — only raw flag text (ADR-005 req 21).

### 2.5 Plan Header Persistence

Flags surviving `--resume` are written to `docs/plans/YYYY-MM-DD-<slug>-map.md` header: `Mode, Autopilot, Accept-ADRs, Lean, Bullets, Skills, Teammate-model, Branch`. A document-mode flag would need a `Document-mode: <true\|false>` field.

---

## 3. Nurture and Secure Mechanics

### 3.1 Invocation Points

1. **T4/T5 in teammate flow**: `/brains:nurture --scope phase-<N>` and `/brains:secure --scope phase-<N>` as Agent subagents. T5 blocked on T4.
2. **Phase 1 option 6**: `--scope phase-1` after inline implementation.
3. **Phase 2 accept-and-skip**: `--scope phase-1`.

Standalone defaults to `--scope all`.

### 3.2 `--scope phase-N` Behavior

Nurture MUST: run `git status --porcelain`, commit atomically with conventional-commit messages, update `.gitignore`, reflect half-complete state in docs. Report path: `docs/plans/<slug>-phase-<N>-nurture.md`.

### 3.3 Council Review in Nurture and Secure

Under `--parallel`/`--debate`, both invoke star-chamber using `review` (not `ask`), passing changed files as review targets. For `--debate`: substitute `review` for `ask` and pass file paths instead of a question string.

### 3.4 Phase Transition Responsibilities

Nurture closes `Nurture: phase <N>`; secure closes `Secure: phase <N>`. Both file follow-ups labelled `brains:phase-<N+1>` or `brains:cleanup`. Secure is the final BRAINS phase.

---

## 4. Star-Chamber `ask` vs `review`

### 4.1 Command Difference

**`ask`** — design-question mode; takes a question string:
```bash
uvx star-chamber ask --context-file "$SC_TMPDIR/context.txt" --format json "Review question here"
```
**`review`** — code-focused review; takes file paths (no question string):
```bash
uvx star-chamber review --context-file "$SC_TMPDIR/context.txt" --format json file1.py file2.py
```
Both share `--context-file`, `--format json`, optional `--council-context`. Both require `uv` + `~/.config/star-chamber/providers.json`.

### 4.2 Which Skills Use Which

| Skill | Command | When |
|---|---|---|
| `/brains:brains` (parallel) | `ask` | Question generation review, ADR review |
| `/brains:map` (parallel) | `ask` | Plan review |
| `/brains:nurture` (parallel) | `review` | Changed files as positional args |
| `/brains:secure` (parallel) | `review` | Security review, code files as positional args |

Nurture and secure are the only two skills using `review`. **This is the closest analog to "review the final documents with the council."**

### 4.3 Prerequisites

`command -v uv` and existence of providers config. Under `--single`, proceed without star-chamber. Under `--parallel`/`--debate`, stop on failure.

---

## 5. ADR Conventions

### 5.1 Filename and Numbering

Format: `docs/adr/YYYY-MM-DD-NNN-<title>.md`. NNN globally sequential. Current highest: ADR-005. **Next available: ADR-006.**

### 5.2 Template Structure

From `skills/brains/references/adr-template.md`:
```
# ADR-NNN: <Title>
**Date:** / **Status:** Accepted / **Decision makers:**
## Context / ## Decision / ## Requirements (RFC 2119) / ## Rationale
## Alternatives Considered / ## Assumed Versions (SHOULD) / ## Diagram
## Consequences / ## Council Input
```

### 5.3 Requirements Style

RFC 2119 MUST/SHOULD/MAY. Numbered globally within the ADR (1, 2, 3...) with letter sub-requirements (a, b, c). Referenced by number in Rationale.

### 5.4 House Style (ADR-005)

- Rationale sub-headings: `**Why X.**`
- Consequences: "New surface introduced:", "Test plan:", "Backward compatibility:", "Risks accepted:"
- Council Input: numbered concerns with severity markers

### 5.5 Diagram Convention

`brains:diagram` populates `## Diagram`. Auto-triggered per heuristics. Stored in `docs/adr/diagrams/<adr-stem>-<type>.svg`.

---

## 6. Manifests

### 6.1 What Manifests Are

Role manifests (`manifests/`) are YAML-frontmatter markdown declaring what context a role loads under `--lean`. Without `--lean`, manifests are ignored.

### 6.2 Current Manifests (8 files)

`phase-1-brains.md`, `phase-2-map.md`, `master-implement.md`, `teammate.md`, `nurture.md`, `secure.md`, `star-chamber-ask.md`, `star-chamber-review.md`.

### 6.3 Manifest Format

YAML frontmatter: `role:`, `applies-under: --lean`. Sections: `## Skill`, `## References`, `## Artifacts`, `## Live context`. Reference modes: `full`, `compact-excerpt`, `lazy-on-demand`. Artifact modes: `full`, `summary-with-drill-down`, `whole-always` (**ADRs MUST use `whole-always`**).

### 6.4 CI Validation

`scripts/manifest-lint.sh` validates on every PR. `ALLOWED_ROLES` hardcoded (lines 40–49): `phase-1-brains, phase-2-map, master-implement, teammate, nurture, secure, star-chamber-ask, star-chamber-review`. A new role requires a new `manifests/<role>.md` AND adding the role to `ALLOWED_ROLES`.

---

## 7. Document/Dependency Detection

### 7.1 Existing Detection Logic

**Zero existing document-type detection logic.** No skill inspects `git diff --name-only` to classify changes, nor filters by extension. The only doc-awareness is in `skills/suggest/SKILL.md` "When NOT to Suggest" → "Documentation updates" — a human-readable heuristic, no programmatic detection.

### 7.2 Detection Requirements (all net-new)

- **File-extension classification**: examine `git diff --name-only HEAD` (or vs base ref); classify `.md`, `.mdx`, `.rst`, `.txt`, `.adoc` as document-only. Any non-document extension disqualifies.
- **Dependency counting**: documents ≤4; extract markdown links (`[text](path)`, `[ref]: path`) from each changed doc, count unique referenced files that exist on disk (≤10).
- No existing utility functions for either. Both net-new (bash or LLM-based).

### 7.3 Auto-Invocation Trigger Point

No existing file-classification hook. Candidate trigger points: start of `/brains:brains` Step 1, or a guard in the `suggest` skill. Both net-new.

---

## 8. README/CHANGELOG/Versioning Surface Area

- **Plugin version**: `0.5.0` in `.claude-plugin/plugin.json`. New feature → `0.6.0` (minor).
- **CHANGELOG**: Keep a Changelog format. New entry under `## [Unreleased]`, move to `## [0.6.0]` at release. CHANGELOG entry required for user-visible changes (ADR-005 req 28).
- **README sections affected**: Skills table, Configuration `--no-*` flags, `flags` object table (`document_mode` key), flag description prose, examples block.
- **`settings-format.md`**: update `flags` schema example, flags table, `brains.local.md` Flags table example.
- **`skills/setup/SKILL.md`**: add key to global JSON, add row to local Flags table, handle non-destructive migration.

---

## 9. Idiomatic Patterns

### 9.1 SKILL.md Structure

YAML frontmatter → `# <Name>: <Tagline>` → summary → BRAINS_PATH block → `## Mode Behavior` table → `## Hard Gate` → optional flag H2s → `## Process` (numbered steps) → `## Output` → `## Phase Transition` → `## Additional Resources`.

### 9.2 Mode Behavior Table

Immediately after intro. Columns: `Mode` + `Flow`/`Plan review`/etc. MUST have `--single`, `--parallel` (default), `--debate` rows.

### 9.3 Flag Resolution Block Pattern

```
**Flag resolution for `--<flag>`** (per ADR-005 reqs 18-19): walk the chain top-to-bottom, stop at first definitive value:
1. Explicit CLI flag — `--<flag>` / `--no-<flag>` wins.
2. `.claude/brains.local.md` Flags table — row with `true`/`false`.
3. `~/.config/brains/defaults.json` `flags` object — `flags.<key>`.
4. Built-in default — `false`.
```

### 9.4 Flag Description Prose Pattern

```
`--<flag>` is an orthogonal flag that composes with [modes/flags]. When present, [behavior]. Default [value]. [Propagation note].
```

### 9.5 Other Patterns

- Step naming: action-verb + noun; subagent steps note "(subagent)".
- Phase transition: blockquote `> "Phase N complete. ..."` + per-option invocation instructions.
- Additional Resources: bulleted `$BRAINS_PATH/...` with one-line descriptions.
- BRAINS_PATH block opens every SKILL.md/teammate.md.
- Sub-skill invocation: slash-command-with-flags string, not SKILL.md path.
- Commits: conventional-commit format.

---

## Net-New Pieces for Document Mode

| Component | Status | Notes |
|---|---|---|
| 4-layer flag resolution | Exists | Copy `--skills` block |
| Plan header persistence | Exists | Add `Document-mode:` field |
| Standalone skill invocation | Exists | nurture/secure precedent |
| Phase 1 gate option 6 | Exists | Closest "skip to inline" precedent |
| star-chamber review invocation | Exists | Used by nurture+secure today |
| File-extension classification | Net-new | No existing logic |
| Dependency/link counting | Net-new | No existing logic |
| Auto-invocation trigger | Net-new | suggest skill proximity, no hook |
| Document-mode manifest | Net-new | New role + ALLOWED_ROLES entry |
| README/CHANGELOG entries | Net-new | Standard update process |
| ADR-006 | Net-new | Next sequential number |

---

## Key Files

- `skills/brains/SKILL.md` — phase 1, flag resolution, gate options
- `skills/map/SKILL.md` — phase 2, plan generation, bullets mode
- `skills/implement/SKILL.md`, `skills/implement/teammate.md` — phase 3, T1–T6, T4/T5 nurture+secure
- `skills/nurture/SKILL.md`, `skills/secure/SKILL.md` — review mechanics, `--scope`, council review
- `references/multi-llm-protocol.md` — ask vs review, parallel/debate flow
- `skills/brains/references/adr-template.md` — ADR structure
- `docs/adr/2026-04-28-005-brains-skills-integration.md` — latest ADR, house style
- `manifests/README.md`, `scripts/manifest-lint.sh` — manifest format, ALLOWED_ROLES, CI rules
- `skills/suggest/SKILL.md` — only existing doc-awareness logic
- `skills/setup/references/settings-format.md`, `skills/map/references/plan-format.md` — flags schema, plan header
- `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json` — flag docs, version
