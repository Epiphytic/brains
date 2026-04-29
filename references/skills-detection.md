# Skills Detection (hotskills probe)

BRAINS shared reference for detecting whether the **hotskills** MCP plugin is available in the current session. Consumed by `skills/brains/SKILL.md`, `skills/map/SKILL.md`, and `skills/implement/SKILL.md` (and per-teammate, by `skills/implement/teammate.md`) when `--skills` resolves to `true`.

> Pair this file with `references/skills-invocation.md` (search/activate/invoke + find-skills fallback) and the vendored `references/find-skills.md` (lazy-loaded only when the fallback fires).

## Hotskills minimum version

- **Hotskills (npm):** `0.1.4` minimum (released 2026-04-28; required for stable `gate_status` semantics).
- **API surface relied on:** tools `hotskills.search`, `hotskills.activate`, `hotskills.invoke`, `hotskills.list`. Field names: `gate_status`, `skill_id`, `installs`.
- **Tool name (current MCP exposure):** `mcp__plugin_hotskills_hotskills__hotskills_search` (and the matching `_activate`, `_invoke`, `_list` variants).

A rename of any tool name or field above silently triggers the find-skills fallback (per ADR-005 req 5 — "detection breakage on hotskills API rename is acceptable failure"). Do NOT crash on a rename; emit the warning per the contract below and fall through.

## Two-step probe procedure

Per ADR-005 req 2, hotskills detection MUST follow this exact order. Do NOT short-circuit either step.

### Step (a): tool-name presence check

Check whether the tool name `mcp__plugin_hotskills_hotskills__hotskills_search` is present in the current session's available tools (the system-reminder block listing MCP tools, or the deferred-tools list, depending on harness version).

- **If absent:** stop probing. Hotskills is unavailable in this session. Skip to fallback (per `references/skills-invocation.md` § find-skills fallback).
- **If present:** proceed to step (b).

This step is zero-cost when the tool is absent — no MCP call is made, so a stale plugin install or disabled MCP server does not generate spurious tool-call traffic.

### Step (b): `hotskills.list` smoke probe

Call `hotskills.list({scope:"merged"})` inside a try/catch.

- **On success (any non-throwing return, including an empty list):** treat hotskills as available for this session.
- **On throw / error / timeout:** fall through to the fallback path. Emit the warning per the contract below.

Why `scope:"merged"`? It returns the full effective merged view (global + project) and exercises the same code path the activation flow uses, so a hidden config-load failure surfaces here rather than at activation time.

## Warning-log contract

Emit a **single-line user-visible warning** when:
- Step (b) throws or times out (probe failed despite tool presence).
- The fallback path fires for any reason after step (a) suggested hotskills was present.

Example messages (use literal strings; do NOT paraphrase across runs):

- Probe failure: `"hotskills detected but list() failed; using find-skills fallback this session"`
- Tool absent (informational, not a warning unless `--skills` was explicitly requested): `"hotskills MCP tool not present; using find-skills fallback this session"`

The warning MUST NOT abort the run. The skill continues with the fallback, or skips skill discovery entirely if the fallback is also unusable (per `references/skills-invocation.md`).

## Per-session independence

Each session probes independently. This includes:

- The **master** `/brains:implement` orchestrator session.
- Each spawned **teammate** session (per `skills/implement/teammate.md` T1.1).
- Any nested subagent that itself invokes `--skills`-aware logic (rare; usually subagents do not re-probe).

The master MUST NOT pass a resolved provider value (e.g., `skills_provider=hotskills`) into the teammate's initial prompt. Only the raw `--skills` / `--no-skills` flag text is propagated. Each teammate's MCP tool surface may differ from the master's (independent agent-teams sessions, different plugin merging order, etc.), so re-probing is correctness, not redundancy.

## Lazy-load expectation

This file (`skills-detection.md`) and `skills-invocation.md` MAY be loaded by the calling skill at the start of a `--skills` run. The vendored `references/find-skills.md` MUST be lazy-loaded only when the fallback actually fires (per ADR-005 req 29). Under `--lean`, the same lazy-load rule applies — no upfront cost when hotskills succeeds or `--skills` is unset.
