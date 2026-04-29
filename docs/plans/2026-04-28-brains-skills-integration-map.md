# Plan: BRAINS `--skills` integration (serial sweep mode)

**Slug:** brains-skills-integration
**ADRs:** docs/adr/2026-04-28-005-brains-skills-integration.md
**Research:** docs/research/2026-04-28-brains-skills-integration-research.md
**Mode:** --parallel
**Autopilot:** true
**Bullets:** true
**Lean:** false
**Teammate-model:** opus (unused under bullets — inline execution)
**Branch:** brains/brains-skills-integration

## Overview

ADR-005 plus 6 user-driven amendments (covering 49 RFC-2119 requirements). Eligible for **serial sweep mode** per ADR-005 req. 45:
- ✅ No new external dependencies or services (npx + gh already in use)
- ✅ Topologically serial — no parallel-independent streams
- ✅ No architectural unknowns

Single plan-phase, 10 coarse beads tasks (8 work + 2 umbrella). Inline execution in the current session — no teammate spawn.

## Phase 1 — Single sweep

### T-1: Foundation
ADR reqs: 11 (vendored doc), 15-17 (defaults.json v0.3.0 + migration + Flags table), 30 (maintenance note), 31-32 (research-path migration)
- [ ] Vendor `references/find-skills.md` from `vercel-labs/skills/main/skills/find-skills/SKILL.md` with maintenance header (source URL, vendor SHA, refresh policy, hotskills API surface paired)
- [ ] Bump `~/.config/brains/defaults.json` schema to v0.3.0; add top-level `flags: { skills: bool, grill: bool }` object
- [ ] Document the schema bump in `skills/setup/references/settings-format.md`
- [ ] Implement non-destructive merge migration in `skills/setup/SKILL.md` step 3 (`--global` path) — preserve existing values, add only missing keys, bump `version`
- [ ] Add `## Flags` table writer to `skills/setup/SKILL.md` step 4 (`--local` path) writing to `.claude/brains.local.md`
- [ ] Add "Vendored documentation maintenance" section to `AGENTS.md` referencing `references/find-skills.md` + refresh policy
- [ ] Migrate research-path convention: `skills/brains/SKILL.md` step 2 writes to `docs/research/`; `skills/map/SKILL.md` step 4 reads from `docs/research/` first, falls back to `docs/plans/` for legacy

**Acceptance:** `bd preflight` passes; `cat ~/.config/brains/defaults.json | jq .version` returns "0.3.0" after migration test; `references/find-skills.md` exists with header; `grep -n 'docs/plans/.*-research' skills/brains/SKILL.md skills/map/SKILL.md` returns 0 matches outside legacy-fallback prose.

### T-2: Skills plumbing — flag parsing + detection + invocation references
ADR reqs: 1-14, 18-22, 29
- [ ] Add `--skills` / `--no-skills` parsing AND `flags.grill` resolution to `skills/brains/SKILL.md` step 1 (precedence chain: CLI > local > global > built-in `false`)
- [ ] Same for `skills/map/SKILL.md` (with `--grill` rejection — phase-1 only)
- [ ] Same for `skills/implement/SKILL.md` (reads `Skills:` from plan header on `--resume`)
- [ ] Create `references/skills-detection.md` documenting tool-name presence check (`mcp__plugin_hotskills_hotskills__hotskills_search`) + `hotskills.list({scope:"merged"})` try/catch + warning-log contract + per-session independence
- [ ] Create `references/skills-invocation.md` documenting query derivation order + autopilot-vs-interactive search/activate/invoke sequence + find-skills fallback (`command -v npx` check + `npx skills find`) + `force_whitelist` MUST NOT under autopilot + no `npx skills add` under autopilot
- [ ] Wire both reference files into at least one upstream caller (verify with `grep -l "skills-detection.md\|skills-invocation.md" skills/`)
- [ ] Update `skills/implement/teammate.md` T1 to parse `--skills` and re-probe locally
- [ ] Update `references/teammate-protocol.md` initial-prompt template to document `--skills` as a forwarded flag (mirroring `--lean`)

**Acceptance:** All three SKILL.md files have updated `argument-hint` frontmatter; both reference files exist with mandatory content per ADR; `--skills --lean` lazy-loads vendored doc only on fallback.

### T-3: Branch + PR lifecycle + link surfacing
ADR reqs: 33-38, 37, 37a, 37b, 37c
- [ ] Add `--accept-adrs` flag to `skills/brains/SKILL.md` step 1; step 9 logic: under `--autopilot` without `--accept-adrs` present ADR gate normally, with `--accept-adrs` auto-select option 2
- [ ] Add `Accept-ADRs:` field to plan header schema (`skills/map/SKILL.md` step 11); `skills/implement/SKILL.md` reads it on `--resume`
- [ ] Hoist branch-creation logic from `skills/map/SKILL.md` step 3 into `skills/brains/SKILL.md` step 9 (BEFORE commit+push); under `--autopilot` auto-create `brains/<slug>` without prompting
- [ ] After ADR commit+push in `skills/brains/SKILL.md` step 9, IF `gh` available + GitHub remote, auto-run `gh pr create --draft --title "<ADR title>" --body-file <ADR path>`; suppress `already exists` errors
- [ ] BEFORE presenting ADR gate options, surface clickable GitHub links: each new ADR file URL + draft PR URL ("Review ADRs:" + "Draft PR:" labels)
- [ ] In `skills/map/SKILL.md` step 7, commit + push plan BEFORE presenting gate options; surface "Plan doc:" link with GitHub URL
- [ ] In `skills/implement/SKILL.md` step 7 (wrap-up), when `Paused: false` AND no `brains:needs-human` outstanding AND `gh` + GitHub remote, run `gh pr ready <number>` (find via `gh pr view --head $(git branch --show-current) --json number -q .number`)

**Acceptance:** Each ADR-005 req 33-38 has a single matching code site; all gate prompts surface the relevant GitHub URLs; PR auto-creation suppresses duplicates with a log; PR auto-ready suppresses already-ready with a log.

### T-4: CI status check in grooming
ADR reqs: 39-43
- [ ] Extend `skills/implement/teammate.md` T2 grooming subagent prompt: AFTER swapping `brains:ready-for-grooming` for `brains:groomed`, IF `git remote get-url origin` matches `github.com` AND `command -v gh`, run `gh run list --limit 10 --branch $(git branch --show-current) --json status,conclusion,name,databaseId,createdAt`
- [ ] For each failed run, check `git rev-parse HEAD~1` history; if NOT pre-existing, file `bd create --title "Investigate CI failure: <workflow>" --type=bug --priority=2 --label brains:topic:<slug> --label brains:phase-<N+1> --label ci-failure` (or `brains:cleanup` if final phase)
- [ ] MUST NOT wait for in-flight runs; MUST NOT block grooming completion; skip silently when `gh` missing or no GitHub remote

**Acceptance:** Grooming subagent prompt explicitly contains the `gh run list` invocation and the HEAD~1 dedup check; behavior is documented as additive (post-grooming) so investigation tickets enter NEXT phase, not current.

### T-5: Nurture doc-update strengthening + teammate.md T4 doc bullet
ADR reqs: 24-28
- [ ] Add bullet to `skills/nurture/SKILL.md` Step 2 completeness checklist: "Are user-facing docs (README, CHANGELOG, ADRs) updated to reflect the changes in this scope?"
- [ ] Add `P1 | Missing docs` row to issue-priority table at same tier as `P1 | Missing test`
- [ ] Extend Step 5 P1 fix block: "Missing features/tests/docs" with README/CHANGELOG fix scope
- [ ] Add bullet to `skills/implement/teammate.md` T4: "When implementing tasks that change user-facing behavior or add new options, update README and CHANGELOG entries in the SAME commit as the code change. Docs land with the code, not as trailing cleanup. If no `CHANGELOG.md` exists at the repo root, file a `bd create` follow-up task rather than creating one unilaterally."

**Acceptance:** All four nurture/teammate edits present; no contradictions introduced (e.g., teammate doesn't unilaterally create CHANGELOG.md when none exists).

### T-6: Documentation — README + CHANGELOG
ADR reqs: README/CHANGELOG-related (T-3.5/T-3.6/T-3.7 from prior plan)
- [ ] Add `--skills` flag prose to `README.md` "Additional flags" subsection (orthogonal, per-session probing, safe under autopilot)
- [ ] Add `--accept-adrs` flag prose (default OFF; `--autopilot` no longer auto-accepts ADRs without it)
- [ ] Add `--bullets` / `--no-bullets` flag prose (auto-detect serial-sweep eligibility)
- [ ] Add 3-4 examples to README examples block: `--skills` use, `--autopilot --accept-adrs` for full hands-off, `--bullets` for inline execution
- [ ] Add new top-level `## Configuration` section: `~/.config/brains/defaults.json` schema v0.3.0, `.claude/brains.local.md` Flags table, 4-layer precedence with examples
- [ ] Create `CHANGELOG.md` at repo root with v0.5.0 entry covering: `--skills`, `--accept-adrs`, `--bullets`, config-default support, nurture doc-update strengthening, research-path migration, branch-creation hoisting, draft-PR lifecycle, ADR/PR/plan link surfacing, CI grooming check. Breaking-change subsection notes `--autopilot` ADR-gate semantic change.

**Acceptance:** README has all three new flags documented + Configuration section; CHANGELOG.md exists with Keep-a-Changelog-style v0.5.0 entry covering all 7 behavior categories.

### T-7: E2E tests (untouchable per star-chamber)
ADR req: Test plan in Consequences section
- [ ] Test 1: tool-name absent → fallback fires + `npx skills find` invoked
- [ ] Test 2: `hotskills.list` throws → fallback + warning logged
- [ ] Test 3: `--skills --autopilot` with `gate_status=allow` → activation, `force_whitelist` NOT passed
- [ ] Test 4: `--skills --autopilot` with no allow-status → log + skip, autopilot continues
- [ ] Test 5: `npx` absent → clear error + skill discovery skipped
- [ ] Test 6: Config migration v0.1.0 → v0.3.0 preserves prior values

**Acceptance:** Tests live under `scripts/test/` (verify path with `ls scripts/test/`; if absent, create + file follow-up task to wire into project test harness); each test is executable from repo root and exits 0 on success; teammate documents exact invocation in test header comment.

### T-8: Implement `/brains:map --bullets` mode itself (META — implements ADR req 44-49)
ADR reqs: 44-49 (the bullets-mode design itself)
- [ ] Add `--bullets` / `--no-bullets` parsing to `skills/map/SKILL.md` step 1
- [ ] Add `Bullets:` plan-header field to `skills/map/SKILL.md` step 11; `skills/implement/SKILL.md` reads on `--resume`
- [ ] Implement auto-detection in `skills/map/SKILL.md` step 5 (high-level plan generation): pass eligibility prompt to planning subagent, default to bullets shape when all 3 conditions hold (no new deps/services, topologically serial, no risk:high or unknowns)
- [ ] Update `skills/map/references/plan-format.md` with new "Serial Sweep Mode" section showing 1-phase 3-6 task shape with bullet sub-checklists
- [ ] Step 7 user gate under bullets: default "Accept and skip teammate spawn" — inline execution
- [ ] If grooming subsequently surfaces risk:high, escalate back to standard shape with one-line warning

**Acceptance:** `--bullets` flag accepted; auto-detection works against the 3-condition heuristic; plan-format.md documents both modes; example plan in this ADR delivery serves as the canonical bullets-mode reference.

### T-9: Nurture review (single pass — no per-phase splits)
- [ ] Run `/brains:nurture --scope all` against the changes from T-1..T-8
- [ ] Validate each ADR-005 requirement (1-49) has a code site
- [ ] Verify README/CHANGELOG/AGENTS.md mentions are accurate
- [ ] File any P1 issues for completeness gaps; fix in priority order
- [ ] Commit + push fixes

**Acceptance:** `docs/plans/2026-04-28-brains-skills-integration-nurture.md` exists with `Issues Fixed` section; all P0/P1 issues resolved or filed as cleanup tickets; full E2E test suite passes.

### T-10: Secure review (single pass)
- [ ] Run `/brains:secure --scope all` against the changes
- [ ] Review: vendored `find-skills.md` for embedded scripts, merge migration for path-traversal/JSON-injection risks, bash invocations of `npx skills find` for command-injection on derived query, MCP tool error handling for leaked stack traces, query derivation for PII/secrets in prompts, README examples for misleading flag combos, CHANGELOG for accidentally-leaked secrets, test harness for hardcoded credentials
- [ ] Fix any P0/P1 findings
- [ ] Commit + push

**Acceptance:** `docs/plans/2026-04-28-brains-skills-integration-secure.md` exists with findings; PR draft → ready transition runs at end of inline execution.

## Wrap-up

After T-10 completes:
- Generate `docs/plans/2026-04-28-brains-skills-integration-wrap-up.md`
- Run `gh pr ready <PR#4>` to transition draft → ready (per ADR req 37a)
- Surface PR URL to user for final review/merge
