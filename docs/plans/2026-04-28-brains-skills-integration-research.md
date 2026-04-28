# BRAINS `--skills` Integration Research

**Date:** 2026-04-28
**Slug:** brains-skills-integration
**Topic:** Add `--skills` option that integrates with epiphytic/hotskills (preferred) or vercel-labs/skills find-skills (fallback). Config defaults for `--skills` and `--grill`. Nurture updates docs/changelogs/readmes/tests as it goes. Propagate `--skills` to teammates.

---

## 1. Existing Flag-Handling Patterns — `--lean` End-to-End Trace

### Flag Taxonomy

BRAINS flags fall into three groups:

**Mode flags (mutually exclusive):** `--single`, `--parallel`, `--debate`. One is always active (default is `--parallel` for brains/map/implement; `--single` for nurture/secure).

**Orthogonal modifier flags (compose freely):** `--autopilot`, `--lean`. Both propagate through all phases. `--grill` is orthogonal but phase-1-only — it explicitly does NOT propagate.

**Phase-scoped sub-flags:** `--rounds N`, `--max-diagrams N`, `--no-diagram`, `--diagram <type>` (phase 1); `--teammate-model`/sugar aliases, `--no-escalate-on-retry`, `--ignore-model-hints`, `--resume`, `--slug` (phase 3 master); `--scope phase-N` (nurture/secure).

### Parsing Location

Every flag is parsed in **Step 1** of each SKILL.md, with no shared utility function. The argument-hint YAML frontmatter field documents accepted flags per skill:

- `brains/SKILL.md` line 5: `argument-hint: "[--single|--parallel|--debate] [--autopilot] [--lean] [--grill] [--rounds N] [--max-diagrams N] [--no-diagram] [--diagram <type>] [topic]"`
- `map/SKILL.md` line 5: `argument-hint: "[--single|--parallel|--debate] [--autopilot] [--lean] [--rounds N] [topic]"`
- `implement/SKILL.md` line 5: `argument-hint: "[--single|--parallel|--debate] [--autopilot] [--lean] [--teammate-model ...] [--no-escalate-on-retry] [--ignore-model-hints] [--resume] [--slug <slug>]"`

### `--lean` Trace: Phase 1 (`skills/brains/SKILL.md`)

**Step 1 parse** (`SKILL.md:43-44`): When `--lean` is present, activate the token-efficiency path: use compact multi-llm-protocol excerpt instead of full file; consult role manifest at `manifests/phase-1-brains.md`.

**Step 2 research** (`SKILL.md:59`): After writing the research doc, produce a compact `research-summary` YAML block and stash it at `docs/plans/YYYY-MM-DD-<slug>-research-summary.yaml` for phase-2 to embed.

**Behavior unchanged by `--lean`:** question generation, questionnaire, synthesis, review, ADR writing — byte-identical to non-lean.

**Phase transition** (`SKILL.md:207-211`): At the ADR gate, option 1 chains into `/brains:map [mode] --lean`; option 2 chains into `/brains:map --autopilot [mode] --lean`. The flag is forwarded verbatim in the invocation string.

### `--lean` Trace: Phase 2 (`skills/map/SKILL.md`)

**Step 1 parse** (`SKILL.md:48`): `--lean` activates: compact protocol excerpt; read only `research-summary` block (not full research doc) — drill into full doc only when a summary field is empty-but-relevant, task flagged `risk:high`, or `--ignore-research-summary`; follow role manifest at `manifests/phase-2-map.md`.

**Step 11 plan header** (`SKILL.md:125-159`): `Lean: <true|false>` is written to `docs/plans/YYYY-MM-DD-<slug>-map.md`. This persists the flag for `--resume`.

**Phase transition** (`SKILL.md:162-168`): Chains into `/brains:implement [mode] --lean` (or with `--autopilot` if set).

### `--lean` Trace: Phase 3 (`skills/implement/SKILL.md`)

**Step 1 parse** (`SKILL.md:52`): `--lean` activates: teammates receive only `skills/implement/teammate.md` not full master SKILL.md; compact multi-llm-protocol excerpt; `failure-recovery.md` lazy-loaded on first failure; role-scoped context per `manifests/master-implement.md`, `manifests/teammate.md`, `manifests/nurture.md`, `manifests/secure.md`.

**Step 2 load plan** (`SKILL.md:104-109`): `Lean:` field read from plan header on `--resume`. CLI `--lean` overrides persisted value.

**Teammate spawn** (`SKILL.md:169`): Mode flag and `--lean` included in initial prompt per `references/teammate-protocol.md` template.

### `--lean` Trace: Teammate Side (`skills/implement/teammate.md`)

**T1** (`teammate.md:26-27`): Reads mode and `--lean` from the initial prompt. Under `--lean`: compact multi-llm-protocol excerpt used; `failure-recovery.md` lazy-loaded on first task failure.

### `--grill` Non-Propagation Contract

`brains/SKILL.md:45` is explicit:

> "`--grill` applies to phase-1 steps 3 and 5 only; it does NOT propagate to `/brains:map` or `/brains:implement`, and it MUST NOT be forwarded to any chained skill."

The grill protocol file (`skills/brains/references/grill-protocol.md`) is lazy-loaded — zero cost on non-grill runs. This is the only currently documented explicit non-propagation constraint.

### `--autopilot` Propagation (Parallel to `--lean`)

`map/SKILL.md:38-39`: "Autopilot is propagated downstream — the inherited state is persisted in the plan header and honored by `/brains:implement --resume`." Written as `Autopilot: true/false` in the plan header alongside `Lean:`.

---

## 2. Existing Config/Defaults System

### Three-Layer Precedence (from `skills/setup/references/settings-format.md`)

| Priority | Source | Mechanism |
|---|---|---|
| 1 (highest) | Explicit CLI flags | Always win |
| 2 | `.claude/brains.local.md` | Auto-loaded by Claude Code; skills do NOT read it explicitly |
| 3 | `~/.config/brains/defaults.json` | Read by skills via the Read tool when no local override |
| 4 (lowest) | Built-in defaults | Hardcoded in each SKILL.md |

### Global Defaults: `~/.config/brains/defaults.json`

Written by `/brains:setup --global` step 3 (`setup/SKILL.md:246-261`). Read by skills via the Read tool.

**Documented schema (v0.2.0):**
```json
{
  "version": "0.2.0",
  "defaults": {
    "brains": "parallel",
    "map": "parallel",
    "implement": "parallel",
    "nurture": "single",
    "secure": "single"
  },
  "debate_rounds": 2
}
```

Fields: `version` (string), `defaults` (object mapping skill name → mode string), `debate_rounds` (number). No boolean flag defaults exist in this schema.

**Live state at `/home/liamhelmer/.config/brains/defaults.json`:** The file exists but contains a stale v0.1.0 snapshot with wrong skill names (storm, research, architect — pre-rename keys from an earlier BRAINS version). The `debate_rounds: 2` field is correct.

### Local Project Settings: `.claude/brains.local.md`

Written by `/brains:setup --local` step 4 (`setup/SKILL.md:309-316`). Auto-loaded by Claude Code as project context. Gitignored by convention.

**Format:** Markdown with YAML frontmatter (`type: settings`, `plugin: brains`). Body contains a human-readable mode table and `Debate Rounds` field. Optionally contains a provider filter.

**Live state:** `/home/liamhelmer/repos/epiphytic/brains/.claude/brains.local.md` does NOT exist in this project.

### Runtime Settings: `.claude/settings.local.json` (`brains` key)

Used for operational knobs, not mode defaults. Not written by the setup skill — documented in `setup/references/settings-format.md` as a reference.

**Documented keys under `brains`:**

| Key | Default | Description |
|---|---|---|
| `baseBranches` | `["main","master","develop"]` | Triggers branch-creation offer |
| `pollingIntervalSeconds` | 15 | Beads/marker poll interval |
| `teammateIdleTimeoutSeconds` | 3600 | Crash threshold |
| `userResponseTimeoutSeconds` | 14400 | Pause threshold |
| `researchStalenessSeconds` | 3600 | Research doc freshness check |
| `completionMarkerDir` | `docs/plans/.state` | Marker file directory |
| `escalateOnRetry` | `true` | 3rd-retry-on-orchestrator flag |

**Live state:** `~/.claude/settings.local.json` contains `{"brains": {"teammateModel": "opus"}}` — a single key not in the documented schema (likely added manually or by an earlier BRAINS version).

### Other Config Files

**`~/.config/brains/renderer.json`** — written by `--with-kroki`; contains `kroki_url`, `kroki_runtime`, `kroki_started_at`, `kroki_network`, `kroki_companion`. Not a user defaults file.

**`~/.config/brains/companion.json`** — optional; `{"start_port": N}` for visual companion port pinning.

### What Is Missing for `--grill` and `--skills` Defaults

The current `defaults.json` schema has no provision for boolean flag defaults. There is no documented key for enabling `--grill` by default or a future `--skills` by default. The `settings.local.json` `brains` key is the only existing home for boolean runtime flags (`escalateOnRetry`), but it is not surfaced by the setup skill and has no schema defined in `defaults.json`.

The `.claude/brains.local.md` format also covers only mode strings and debate rounds — no boolean flag defaults.

---

## 3. hotskills Plugin Discovery and Invocation

### Plugin Identity

- **Repository:** `https://github.com/Epiphytic/hotskills` (TypeScript, ~80%)
- **npm package name:** `hotskills`
- **npm version:** 0.1.4 (as of 2026-04-28)
- **Plugin manifest (`.claude-plugin/plugin.json`):** `name: "hotskills"`, `version: "0.1.0"` (lags npm)
- **MCP server launch:** `npx -y hotskills` (no local build; npm fetches on first run)
- **`.mcp.json` at plugin root:** `{"mcpServers": {"hotskills": {"command": "npx", "args": ["-y", "hotskills"]}}}`

### Installation State on This Machine

**`~/.config/hotskills/config.json`** exists at `/home/liamhelmer/.config/hotskills/config.json` — this is the v1 default schema written by `/hotskills-setup`. `activated: []` (empty when checked at start of session; one skill activated during this session). This confirms `/hotskills-setup` was run at least once.

**`~/.claude/settings.json` `enabledPlugins`:** hotskills is NOT listed. The plugin is set up at the filesystem level but is not currently enabled as a Claude Code plugin. The MCP servers block in `~/.claude/settings.json` lists only `linkedin` — hotskills MCP is not registered there either.

### MCP Tools (Exact Names as Registered)

| Registered tool name | Purpose |
|---|---|
| `hotskills.search` | Ranked skill discovery; 1h cache TTL; dispatches to skills.sh API or npx CLI |
| `hotskills.activate` | Gate validation (whitelist → audit → heuristic → install threshold) + materialization |
| `hotskills.invoke` | Returns substituted SKILL.md body + script/reference inventory; never executes |
| `hotskills.list` | Returns activated skills by scope (project / global / merged) |
| `hotskills.deactivate` | Removes skill from allow-list |
| `hotskills.audit` | Returns cached audit data + gate preview |

ADR-001: "The MCP server MUST register exactly these six tools at connect time." Per ADR-001, Claude Code does NOT honor MCP `notifications/tools/list_changed`, so these six tools are fixed at session start — no dynamic registration.

### Skill Identifier Format

`<source>:<owner>/<repo>:<slug>` — examples:
- `skills.sh:vercel-labs/skills:find-skills`
- `skills.sh:obra/superpowers:requesting-code-review`

### Slash Commands

| Command | Effect |
|---|---|
| `/hotskills` | No args: lists activated skills; prompts for query if empty |
| `/hotskills [query]` | Searches, presents ranked picker |
| `/hotskills [query] --auto` | Auto-activates top `gate_status==="allow"` result |
| `/hotskills [query] --source <owner/repo>` | Restricts search to one source |
| `/hotskills --whitelist <skill_id>` | Bypasses security gate (requires explicit `y` confirmation) |
| `/hotskills-setup` | First-time setup (idempotent): MCP registration, config init, find-skills activation, .gitignore patch, API verification |

### Runtime Detection: How a BRAINS Skill Can Detect hotskills

Four detection signals, from most to least reliable:

**Signal 1 — MCP tool probe (most reliable, tests full stack):**
Attempt to call `hotskills.list({ scope: "merged" })`. Success means the MCP server is running and tools are reachable. A tool-not-found error means hotskills is absent or not registered. This tests npm, server launch, and registration simultaneously.

**Signal 2 — Config file existence:**
Check `~/.config/hotskills/config.json`. Existence confirms `/hotskills-setup` was run. Does NOT guarantee the plugin is currently enabled or MCP server is reachable (server is only spawned when plugin is enabled and Claude Code starts a session).

**Signal 3 — `claude mcp get hotskills` CLI check:**
Run `claude mcp get hotskills 2>&1` via Bash. This is the exact check used by `/hotskills-setup` step 1:
- Output contains "No MCP server found" → not registered
- Output contains "Status: ✓ Connected" → registered and working
- Output contains "Status: ✗ Failed to connect" → registered but unhealthy

**Signal 4 — `enabledPlugins` key in settings.json (unreliable):**
hotskills can be registered as a user-level MCP without being in `enabledPlugins`. Absence from `enabledPlugins` does not mean hotskills is unavailable.

### Invocation Flow (from `commands/hotskills.md` Case C)

For a BRAINS skill calling hotskills programmatically to find and use a skill:

1. Call `hotskills.search({ query: "<derived query>", limit: 10 })` → returns ranked results with `gate_status`, `skill_id`, install count, audit summary
2. For `--auto` behavior: find first result with `gate_status === "allow"`, call `hotskills.activate({ skill_id })` → returns materialized cache path
3. Call `hotskills.invoke({ skill_id })` → returns `{ body, path, scripts, references, args_passed }`
4. The `body` field is the substituted SKILL.md content with `${SKILL_PATH}` resolved to the absolute cache path
5. Follow the SKILL.md instructions from `body`

`hotskills.invoke` never executes scripts. Script execution requires the calling model to use its Bash tool explicitly, subject to Claude Code's permission model.

### Materialization Cache Layout

`${HOTSKILLS_CONFIG_DIR}/cache/skills/<source>/<owner>/<repo>/<slug>/` (default: `~/.config/hotskills/cache/skills/`)

---

## 4. vercel-labs/skills find-skills as Fallback

### What find-skills Is

`find-skills` is a **plain markdown instruction document** — a SKILL.md that the LLM reads and follows as instructions. It has no YAML frontmatter (no `allowed-tools`, no `argument-hint`) and is not a Claude Code plugin SKILL.md with the standard frontmatter. It is an agent instruction document that teaches how to use the `npx skills` CLI.

### Full Behavior (from raw content at `skills/find-skills/SKILL.md`)

**When to activate:** User asks "how do I do X", "find a skill for X", "is there a skill that can...", wants to extend capabilities, mentions needing domain-specific help.

**Six-step process:**

1. **Understand the need** — identify domain, specific task, likelihood of existing solutions
2. **Check the leaderboard first** — browse `https://skills.sh/` before CLI searches; top skills: `vercel-labs/agent-skills` (React, Next.js; 100K+ installs), `anthropics/skills` (frontend design; 100K+ installs)
3. **Search** — `npx skills find [query]`; use specific keywords ("react performance" not "performance"); try alternative terms if initial search fails
4. **Verify quality** — prefer 1K+ installs; prefer official sources (vercel-labs, anthropics, microsoft); GitHub stars < 100 = skepticism; install count < 100 = caution
5. **Present findings** — skill name, install count, source reputation, install command, skills.sh link
6. **Offer installation** — `npx skills add <owner/repo@skill> -g -y` (`-g` = global install, `-y` = skip confirmation prompts)

**When no skills found:** Acknowledge absence, offer direct help, suggest `npx skills init` to create custom skill.

**Key CLI commands:**
- `npx skills find [query]` — search
- `npx skills add <package>` — install from GitHub or other sources
- `npx skills check` — check for updates
- `npx skills update` — update all installed skills

### Repository Version

- **Latest release:** v1.5.1 (April 17, 2025)
- **v1.5.1 change:** Single fix — skip LFS smudge during clone
- **Total releases:** 25

### How a BRAINS Skill Would Obtain and Follow find-skills Without hotskills

**Method A — WebFetch at invocation time:**
URL: `https://raw.githubusercontent.com/vercel-labs/skills/main/skills/find-skills/SKILL.md`. Use the WebFetch tool to retrieve content, then read and follow the instructions. Requires network access. No caching.

**Method B — Vendor a copy in BRAINS:**
Store a copy at e.g. `references/find-skills.md` or `skills/skills/find-skills.md` inside the BRAINS plugin. Avoids network round-trip, pins version. This is what hotskills itself does for vercel-labs skill types — it vendors them at `vendor/vercel-skills/` (SHA `bc21a37a`).

**Method C — Direct CLI invocation via Bash:**
Skip the SKILL.md entirely and directly run `npx skills find [query]` via the Bash tool, then parse the output. Requires Node.js and npm on PATH.

### Difference Between hotskills and Direct find-skills Invocation

| Aspect | hotskills path | Direct find-skills path |
|---|---|---|
| Security gating | 4-layer gate (whitelist → audit → heuristic → install threshold) | None — only text heuristics in find-skills instructions |
| Materialization | Automatic to `~/.config/hotskills/cache/skills/` | Manual: `npx skills add <pkg>` |
| Search backend | skills.sh API with fuzzy matching | `npx skills find` CLI (substring on slug only) |
| Caching | 1h search TTL, 24h audit TTL, 7d skill TTL | None |
| Integration with BRAINS | MCP tool calls | Bash subprocess |
| Installation state | `~/.config/hotskills/config.json` allow-lists | `npx skills add -g` writes to global skills location |

---

## 5. Nurture Skill Behavior

Source: `skills/nurture/SKILL.md`

### When nurture Runs

Two modes:
1. **Standalone:** `/brains:nurture [--single|--parallel|--debate] [--scope all | phase-N] [paths...]`
2. **Phase-3 T4 invocation:** After all phase-N implementation tasks close (or at pause-timeout), teammate invokes `/brains:nurture --scope phase-<N>` as a subagent

### Process Structure

1. Gather context — reads `docs/plans/`, ADRs, `git log --oneline -20`, `git diff main...HEAD --stat`, test coverage
2. Conduct review — completeness, correctness, test coverage, code quality, integration
3. Council review (if `--parallel`/`--debate`) — star-chamber review with focus on bugs, missing features, test gaps, integration issues
4. Compile issue list — prioritized table; **presents to user and gets approval before fixing**
5. Fix issues in priority order (P0 bugs → P1 missing features/tests → P2 quality)
6. Verify — full test suite, E2E tests, no regressions

### Does nurture Currently Update README/CHANGELOG/Docs?

**No, not as a standard step.** The only doc-update instruction is in the `--scope phase-N` "Commit and .gitignore responsibilities" subsection (`SKILL.md:112-126`), specifically step 3:

> "Reflect half-complete state in docs (if phase ended early). If the teammate is running nurture during a pause/timeout, explicitly document in the nurture report which tasks are complete, which are in-progress, and which are blocked. Update any user-facing docs (README, architecture docs) affected by partial work to flag the incomplete state."

This condition fires only during pause/timeout. Under normal phase completion, there is no instruction to update README, CHANGELOG, or architecture docs.

The completeness review criteria at step 2 (`SKILL.md:50-57`) covers "Does the code implement everything in the design spec?" and "Are there TODO comments, placeholder implementations?" — but not "Is the README updated?" or "Is the CHANGELOG updated?".

### Does nurture Require/Encourage Tests?

Tests are first-class, mandatory P1 items:

- **Step 2 test coverage checklist** (`SKILL.md:61-65`): "Do end-to-end tests exist that verify the user-facing behavior?", "Are critical paths tested?", "Can the tests be run and do they pass?"
- **Issue priority table** (`SKILL.md:101-108`): `P1 | Missing test` — same priority tier as `P1 | Missing feature`
- **Fix order** (`SKILL.md:133`): "P1 (Missing features/tests): Implement according to the design spec. Write E2E tests for missing coverage."
- **Verify step** (`SKILL.md:142-148`): "Run the full test suite. Verify E2E tests pass. Check that all P0 and P1 issues are resolved."

Tests will be written by nurture if missing. The emphasis is on E2E (user-facing behavior) over unit tests.

### Where a "Always Update Docs/Changelogs/READMEs/Tests As You Go" Instruction Would Hook In

Five candidate insertion points:

**Option A — Step 2 "Completeness" checklist** (after `SKILL.md:57`): Add a bullet: "Are user-facing docs (README, CHANGELOG, ADRs) updated to reflect the changes in this scope?" Issues found here become P1 items in the issue list.

**Option B — Issue list step 4** (add a new priority tier or item): "P1 | Missing docs — README/CHANGELOG not updated for user-visible changes."

**Option C — Step 5 "Fix Issues" P1 block** (`SKILL.md:133`): Extend to "P1 (Missing features/tests/docs): Implement missing features, write E2E tests, update README/CHANGELOG."

**Option D — `--scope phase-N` "Commit and .gitignore responsibilities"** (extend step 3 at `SKILL.md:123-126`): Change "if phase ended early" → "always". Add: "Update README if new user-facing behavior was added. Update CHANGELOG with a new entry for this phase's changes."

**Option E — `teammate.md` T4 block** (`teammate.md:54-62`): A new bullet — "updating README and CHANGELOG for user-visible changes" — visible to every teammate.

---

## 6. Teammate Flag Propagation in `/brains:implement`

### The Core Mechanism: Initial Prompt String

Flags reach teammate Claude Code instances via the **initial prompt string** — passed as a quoted string argument to `claude` in tmux mode, or as the prompt field in the agent-teams spec. There are no environment variables or files written for flag propagation.

**tmux mode** (`implement/SKILL.md:172-173`):
```bash
tmux split-window -h "claude '<initial prompt>'"
```

**agent-teams mode** (`implement/SKILL.md:174-177`):
`TeamCreate` with the initial prompt in the teammate spec's prompt field.

### What the Initial Prompt MUST Include

Per `references/teammate-protocol.md` § Teammate Initial Prompt Template:

1. Path(s) to accepted ADR(s) in `docs/adr/`
2. Path to the plan document (`docs/plans/<slug>-map.md`)
3. Phase label (e.g., `brains:phase-2`)
4. **Mode flag inherited from master** (`--single | --parallel | --debate`)
5. Path to completion marker file (`docs/plans/.state/<slug>-phase-N-marker.json`)
6. Behavioral constraints (beads task scope)

The mode flag (item 4) and any additional text flags (like `--lean`) are included as literal text in the prompt string.

### How `--lean` Reaches Teammates (Concrete Example)

`implement/SKILL.md:52` specifies: "teammates receive only `skills/implement/teammate.md` (not the full master skill body)". Under `--lean`, the initial prompt includes a reference to `teammate.md` rather than embedding the full SKILL.md. The `--lean` flag is also passed as text in the prompt so `teammate.md` T1 can parse it.

### The One Exception: `--teammate-model` in tmux Mode

`implement/SKILL.md:95`: "TEAMMATE_MODEL is propagated to step 5a teammate spawns (as `--model` to the Claude Code CLI for tmux mode, or as the `model` field in the agent-teams teammate spec)."

In tmux mode, `--model` is a **command-line argument** to the `claude` binary, not just text in the initial prompt. This is the only flag that propagates via CLI arg rather than prompt text.

### Flags NOT Forwarded to Teammates

- `--grill` — phase-1 only; `brains/SKILL.md:45` explicitly forbids forwarding
- `--no-escalate-on-retry` — master resolves `escalateOnRetry` from config and encodes the policy in the initial prompt's behavioral constraints
- `--max-diagrams N`, `--no-diagram`, `--diagram <type>` — phase-1 only
- `--resume`, `--slug` — master-side only

### Implication for `--skills`

A new `--skills` flag would propagate via the initial prompt text, following the same pattern as `--lean`. The teammate's instruction file (`teammate.md`) would need to parse it at T1 and act on it.

The resolved state (hotskills available: yes/no, or fallback mode: find-skills-direct) could be encoded in the initial prompt as a resolved value rather than the raw flag, similar to how `TEAMMATE_MODEL` resolves the tier before propagating.

---

## 7. Current Stable Versions and Prior Art

### BRAINS Plugin

- **Version:** 0.4.4 (`/.claude-plugin/plugin.json`)
- **Recent activity:** Merge PR #3 from `brains-v0-5-0` branch is the most recent merge commit per git log; v0.5.0 work is in progress

### hotskills Plugin

| Attribute | Value |
|---|---|
| npm version | 0.1.4 |
| `.claude-plugin/plugin.json` version | 0.1.0 (lags npm) |
| All releases | 0.1.0 through 0.1.4, all released 2026-04-28 (initial public release day) |
| Node.js requirement | ≥ 22 |
| git requirement | ≥ 2.25 (for GitHub-source materialization) |
| jq requirement | hook scripts |
| MCP SDK pinned to | `@modelcontextprotocol/sdk ^1.29.0` |

**Key 0.1.x fixes:**
- 0.1.1: Unsubstituted env placeholder fix; `.mcp.json` simplified (no env block needed)
- 0.1.2: `Permission denied` fix when running via `npx -y hotskills` (chmod 0755 on dist/index.js)
- 0.1.3: Multi-word query normalization; malformed canonical skill ID fix
- 0.1.4: `hotskills.audit` install-gate misleading result fix; optional `install_count` param added

### vercel-labs/skills

| Attribute | Value |
|---|---|
| Latest release | v1.5.1 |
| Release date | April 17, 2025 |
| Total releases | 25 |
| v1.5.1 change | Skip LFS smudge during clone (perf fix only) |
| find-skills location | `skills/find-skills/SKILL.md` on main branch |

### Other Plugins Integrating hotskills as a Sub-Skill

No external Claude Code plugins integrating hotskills as a sub-skill were found at the time of this research. hotskills is a first-day-of-release project (all versions published 2026-04-28). The opportunistic mode (ADR-005) is hotskills' own hook that injects a system reminder suggesting the model call `hotskills.search` — this is the closest existing integration pattern, but it is driven by hotskills itself, not by an external caller.

---

## 8. README.md — Flags, Config, and "How to Enable Defaults" Sections

### Flags in the README

Flags are documented in the **"Modes"** section (`README.md:89-135`).

**Mode flags table** (lines 93-98): `--single`, `--parallel`, `--debate` with behavior descriptions.

**"Additional flags" subsection** (lines 99-135): Eight flags documented with inline prose:
- `--rounds N`
- `--grill` — most detailed: ~150 words covering lifts question cap, relentless-interview policy, 8-turn budget, composed with all other flags, phase-1 only, not propagated
- `--autopilot` — ~100 words covering skips gates, auto-chains, plan header persistence, `--resume` honored
- `--lean` — ~120 words covering compact protocol, research summary, lazy-loads, scoped star-chamber, expected 30-45% savings
- `--teammate-model` — ~100 words covering model selection, sugar aliases
- `--no-escalate-on-retry` — brief, references `settings.local.json` key `brains.escalateOnRetry`
- `--ignore-model-hints` — brief

**Examples block** (lines 117-135): 14 examples covering all major flags and their combinations.

### Config in the README

Config is mentioned only in the **"Installation"** section (lines 66-74), as a list of setup commands. No section describes where config files live, what their schema is, or the precedence order.

### "How to Enable Defaults" — What Is Missing

The README does NOT document:
- `~/.config/brains/defaults.json` path or schema
- `.claude/brains.local.md` path or format
- `settings.local.json` `brains` key and available fields
- The four-layer precedence order (CLI flags > local > global > built-in)

This detail exists only in `skills/setup/references/settings-format.md` (internal to the plugin) and in the `setup/SKILL.md` prose.

### Where `--skills` and Config-Default Docs Would Naturally Land

**Flag documentation:** The "Additional flags" subsection under "Modes" (after line 107). The existing pattern is: flag name in bold, inline prose covering behavior, composition with other flags, any non-propagation contract, and any performance notes.

**Examples:** Two or three new lines in the examples block (lines 117-135).

**Config documentation:** A new "Configuration" section (or an expansion of "Installation") would be needed. Currently no such section exists. It would document the three-level config hierarchy, where to set per-flag defaults, and the precedence order. This is a documentation gap that exists independently of `--skills`.

---

## Essential Files

| File | Purpose |
|---|---|
| `skills/brains/SKILL.md` | Phase 1; flag parsing; `--grill` non-propagation; `--lean`/`--autopilot` forwarding |
| `skills/map/SKILL.md` | Phase 2; flag inheritance; plan header schema |
| `skills/implement/SKILL.md` | Phase 3 master; teammate spawn; initial prompt construction |
| `skills/implement/teammate.md` | Teammate-side protocol; T1 flag reading |
| `references/teammate-protocol.md` | Teammate Initial Prompt Template |
| `skills/nurture/SKILL.md` | Nurture process; test requirements; doc-update hook points |
| `skills/setup/SKILL.md` | Config file creation; `defaults.json` write |
| `skills/setup/references/settings-format.md` | Complete config schema; precedence order |
| `.claude-plugin/plugin.json` | BRAINS version (0.4.4) |
| `~/.config/brains/defaults.json` | Live global defaults (stale v0.1.0 schema) |
| `~/.config/hotskills/config.json` | hotskills global config |

External:
- `https://github.com/Epiphytic/hotskills/blob/main/commands/hotskills.md`
- `https://github.com/Epiphytic/hotskills/blob/main/commands/hotskills-setup.md`
- `https://raw.githubusercontent.com/vercel-labs/skills/main/skills/find-skills/SKILL.md`
