# BRAINS Document Mode — Phase 2 Nurture Report

**Scope:** plan-phase 2 (integration, config, manifest). Mode: `--parallel`.
**Branch:** `brains/brains-document-mode`.

## Tasks completed

- **T-2.1** — `skills/brains/SKILL.md`: added `--document-mode|--no-document-mode` to the `argument-hint`, a 4-layer flag-resolution block (CLI → `.claude/brains.local.md` Flags table → `~/.config/brains/defaults.json` `flags.document_mode` → built-in `false`) citing ADR-005 reqs 18-19, a Step-1 pre-flight delegation guard (eligibility probe → delegate to `/brains:document` forwarding mode + `--autopilot` + `--lean`, do not continue the pipeline), and the no-propagation note for `/brains:map` and `/brains:implement` (reqs 2-5).
- **T-2.2** — `skills/suggest/SKILL.md`: refined the "Documentation updates" heuristic to point at `/brains:document` (req 6). `references/multi-llm-protocol.md`: added the document-review variant note — `review` on final document paths with the 10,000-word per-document curation gate (req 32).
- **T-2.3** — `skills/setup/references/settings-format.md` and `skills/setup/SKILL.md`: documented and wired `flags.document_mode` (default `false`) into the JSON schema, the flags table, migration logic, the fresh-default block, and the `.claude/brains.local.md` Flags table (req 29). Live `~/.config/brains/defaults.json` was NOT touched.
- **T-2.4** — Added `manifests/document.md` (role `document`) declaring the document skill, its references, the shared commit procedure, and ADR-006 (`whole-always`); appended `document` to `ALLOWED_ROLES` and a cross-ref check in `scripts/manifest-lint.sh`; listed the manifest in `manifests/README.md` (req 30). Phase-1 nit: added `references/commit-procedure.md` to `manifests/nurture.md` References.

## Issues fixed (council review, star-chamber `--parallel`)

One provider (gpt-5.4) returned "good"; the other timed out. Clearly-correct, in-scope findings applied:

1. **(high) `--teammate-model` forwarding mismatch** — `/brains:document` accepts `--teammate-model` but `/brains:brains` never parses it. Removed it from the delegation forwarding and clarified the flag is inert in document mode (ADR-006 req 21).
2. **(medium) ambiguous "resolved mode flag"** — clarified the forwarded value is the fully resolved `--single`/`--parallel`/`--debate` after the precedence chain, not the literal CLI token.
3. **(medium) suggest spine duplication** — trimmed the hard-coded document-mode spine in `skills/suggest/SKILL.md` to an advisory pointer to `/brains:document`, reducing drift risk.
4. **(medium) debate-mode document-review gap** — added a debate-mode note in `references/multi-llm-protocol.md` applying the same 10,000-word curation gate per round.
5. **(low) review-input file naming** — added a deterministic `<SC_TMPDIR>/<basename>.review-input.md` convention with a Summary + Curated-excerpt format.
6. **(low) manifest doc-review variant** — named the document-review variant and curation gate in `manifests/document.md`.

### Deferred (out of phase-2 scope)

- Two findings target pre-existing `/brains:brains` Step-9 text (gate-ordering "contradiction" between link-surfacing and option handling; the `--grill --autopilot --accept-adrs` handoff paragraph placement). These are not part of phase-2 edits and were left untouched.

## Verification

- `bash scripts/manifest-lint.sh` → `OK (9 manifests checked, 0 warnings)`, exit 0 (re-run after council fixes).
- All task acceptance greps pass.
- The delegation contract wired in T-2.1 matches `skills/document/SKILL.md` (accepts `--single|--parallel|--debate`, `--autopilot`, `--lean`, optional `--teammate-model`, and is the documented Step-1 delegation target).
