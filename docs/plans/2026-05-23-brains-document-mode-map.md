# Plan: BRAINS document mode

**Slug:** brains-document-mode
**ADRs:** docs/adr/2026-05-23-006-brains-document-mode.md
**Research:** docs/research/2026-05-23-brains-document-mode-research.md
**Mode:** --parallel
**Autopilot:** true
**Accept-ADRs:** false
**Lean:** false
**Bullets:** false
**Skills:** false
**Teammate-model:** opus
**Branch:** brains/brains-document-mode

## Overview

Introduce an abbreviated document-mode fast path for document-only changes, hosted in a new standalone `/brains:document` skill with early delegation from `/brains:brains` Step 1. The work is a markdown-skill plugin: the only automated gate is `scripts/manifest-lint.sh`, which fails if any manifest declares a path that does not yet exist. The phasing is therefore strictly ordered: Phase 1 creates the new skill/reference/template/shared-procedure files (no manifest yet, lint stays green on the unchanged manifest set); Phase 2 wires integration, config, and the new `manifests/document.md` + `ALLOWED_ROLES` entry only after those paths exist — and the manifest's whole-always ADR declaration points at the already-committed ADR-006, so every declared path is on disk (lint passes again); Phase 3 ships docs and the version bump. Each phase ends with `bash scripts/manifest-lint.sh` passing. The plan is intentionally stub-level so re-architecture inside any task remains cheap.

## Phases

### Phase 1: Detection, skill core, template, and shared commit procedure
*End state: new files exist on disk; `manifests/` is unchanged; `bash scripts/manifest-lint.sh` passes (8 manifests, paths intact).*

- [ ] **T-1.1**: Create `skills/document/references/eligibility-detection.md` — hybrid detection reference (ADR reqs 8-17): canonical changed-set definition (unstaged ∪ staged ∪ untracked-not-ignored), versioned document allow-list (`.md/.markdown/.mdx/.rst/.txt/.adoc`; notebooks/diagrams/code excluded), bash classify+count, LLM scope/link resolution with `test -f` confirmation, ≤4-doc / ≤10-dependent ceiling, mode-sensitive threshold behavior (warn-and-ask interactive / detect-then-fallback autopilot with a loud notice), and asymmetric override (oversized→confirm; code files→hard-refuse; in-document code never triggers).
  - Depends on: none
  - Acceptance: `test -f skills/document/references/eligibility-detection.md` exits 0 AND it documents both the ≤4/≤10 ceiling and the allow-list (`grep` for `4` doc ceiling text and each allow-list extension ≥ 1).

- [ ] **T-1.2**: Extract the git-commit / `.gitignore` procedure currently inline in `skills/nurture/SKILL.md` into a shared reference (e.g. `references/commit-procedure.md`) and replace nurture's inline prose with a citation to it (ADR req 28). The shared reference MUST preserve nurture's existing behavior verbatim.
  - Depends on: none
  - Acceptance: the new shared commit-procedure reference exists AND `grep -c` for its path in `skills/nurture/SKILL.md` is ≥ 1.

- [ ] **T-1.3**: Create `skills/document/references/slim-adr-template.md` — the slim-ADR template `/brains:document` follows (ADR req 20): retains Context, Decision, Requirements (RFC 2119), and Consequences; omits Assumed Versions and Diagram; same filename + globally-sequential-NNN convention as the standard template.
  - Depends on: none
  - Acceptance: `test -f skills/document/references/slim-adr-template.md` exits 0 AND it contains the four retained section headings and omits `## Assumed Versions` and `## Diagram` (`grep` confirms presence/absence).

- [ ] **T-1.4**: Create `skills/document/SKILL.md` — canonical entry implementing the abbreviated spine (ADR reqs 1, 7, 18-27): eligibility gate → lightweight research → full 2-4 question questionnaire → slim ADR → inline edits → direct council review (`star-chamber review` + 10k-word `wc` gate, `--single` degraded self-review with warning) → inline commit. Frontmatter MUST set `user-invocable: true` and an `argument-hint`. Body cites the eligibility-detection reference, the slim-adr-template, and the shared commit procedure.
  - Depends on: T-1.1, T-1.2, T-1.3
  - Acceptance: `test -f skills/document/SKILL.md` exits 0; frontmatter contains `user-invocable: true`; body references `eligibility-detection.md`, `slim-adr-template.md`, and the shared commit-procedure path (`grep` ≥ 1 each).

- [ ] **T-1.5**: Confirm Phase-1 lint invariant — no manifest changes were made, and all newly created skill/reference paths exist.
  - Depends on: T-1.1, T-1.2, T-1.3, T-1.4
  - Acceptance: `bash scripts/manifest-lint.sh` exits 0 (still 8 manifests).

### Phase 2: Integration, config, and manifest
*End state: `manifests/document.md` and the `document` role exist; the manifest's whole-always ADR declaration is ADR-006 (already on disk) and all other declared paths were created in Phase 1; `bash scripts/manifest-lint.sh` passes with 9 manifests.*

- [ ] **T-2.1**: Add `--document-mode` / `--no-document-mode` to `/brains:brains` (`skills/brains/SKILL.md`): 4-layer resolution block + `argument-hint` entry, and a Step-1 pre-flight delegation guard that runs the eligibility probe and delegates to `/brains:document` (forwarding mode, `--autopilot`, `--lean`, `--teammate-model`) without continuing its own pipeline (ADR reqs 2-5). MUST note that `--document-mode` does not propagate to map/implement (req 5).
  - Depends on: T-1.4
  - Acceptance: `skills/brains/SKILL.md` contains `--document-mode`, a delegation invocation string to `/brains:document`, and the no-propagation note (`grep` ≥ 1 each).

- [ ] **T-2.2**: Refine `/brains:suggest` "Documentation updates" heuristic to point at `/brains:document` (req 6); add the document-review variant note (`review` with full-document context + 10,000-word curation gate) to `references/multi-llm-protocol.md` (req 32).
  - Depends on: none
  - Acceptance: `grep` for `/brains:document` in `skills/suggest/SKILL.md` ≥ 1 AND `grep` for the 10,000-word document-review note in `references/multi-llm-protocol.md` ≥ 1.

- [ ] **T-2.3**: Add the `flags.document_mode` boolean (default `false`) across config surfaces (req 29): document it in `skills/setup/references/settings-format.md`, and have `skills/setup/SKILL.md` write it into the global `defaults.json` `flags` object and into the `.claude/brains.local.md` Flags table row.
  - Depends on: none
  - Acceptance: `grep -l document_mode` matches both `skills/setup/references/settings-format.md` and `skills/setup/SKILL.md`.

- [ ] **T-2.4**: Add `manifests/document.md` (role `document`) declaring `skills/document/SKILL.md`, `skills/document/references/eligibility-detection.md`, `skills/document/references/slim-adr-template.md`, and ADR-006 (`docs/adr/2026-05-23-006-brains-document-mode.md`, already committed) with `whole-always`; append `document` to `ALLOWED_ROLES` in `scripts/manifest-lint.sh` (req 30). Every declared path MUST already exist on disk.
  - Depends on: T-1.1, T-1.3, T-1.4, T-2.1
  - Acceptance: `bash scripts/manifest-lint.sh` exits 0 reporting 9 manifests checked.

### Phase 3: Documentation and release
*End state: user-facing docs and version reflect document mode; `bash scripts/manifest-lint.sh` still passes.*

- [ ] **T-3.1**: Update `README.md` to document `/brains:document`, the `--document-mode` flag (with the 4-layer chain reference), and the eligibility ceiling (≤4 docs / ≤10 dependents) (req 31).
  - Depends on: T-2.1, T-2.4
  - Acceptance: `grep` for both `/brains:document` and `--document-mode` in `README.md` ≥ 1 each.

- [ ] **T-3.2**: Add a `CHANGELOG.md` entry under `[Unreleased]`/`[0.6.0]` and bump `.claude-plugin/plugin.json` version `0.5.0` → `0.6.0` (req 31).
  - Depends on: T-2.1
  - Acceptance: `grep '"version": "0.6.0"' .claude-plugin/plugin.json` exits 0 AND `CHANGELOG.md` contains a document-mode entry.

- [ ] **T-3.3**: Final verification — full lint pass on the release-ready tree.
  - Depends on: T-3.1, T-3.2
  - Acceptance: `bash scripts/manifest-lint.sh` exits 0.
