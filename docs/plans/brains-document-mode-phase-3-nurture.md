# Phase 3 Nurture — brains-document-mode

**Phase:** 3 (documentation + release) · **Mode:** --parallel · **Date:** 2026-05-23

Scope: README.md, CHANGELOG.md, .claude-plugin/plugin.json (ADR-006 req 31). No skill/manifest/flag changes from phases 1–2 were altered.

## Self-review (against ADR-006 + existing docs)

- README documents `/brains:document` (the abbreviated doc-only fast path), the full spine, the nurture+secure → direct council review replacement, the `--document-mode` / `--no-document-mode` flag with the 4-layer chain reference (consistent with the `--skills` / `--bullets` prose pattern), and the ≤4-document / ≤10-dependent eligibility ceiling including the asymmetric code-file override and the warn-and-ask vs detect-then-fallback behavior. `/brains:document` added to the Skills table, both flags tables, the `defaults.json` example, the plugin-structure tree (verified the referenced reference files exist on disk), and the examples block. Acceptance: `grep` for `/brains:document` and `--document-mode` each ≥ 1 (8 and 7 respectively).
- CHANGELOG gains a new `## [0.6.0] - 2026-05-23` section above `## [0.5.0]` (no `[Unreleased]` section existed), Keep-a-Changelog format, `### Added` / `### Changed` consistent with the 0.5.0 entry; plus a `[0.6.0]:` release link matching the existing link style.
- `.claude-plugin/plugin.json` version bumped `0.5.0` → `0.6.0`. Verified `marketplace.json` carries a separate, stale `0.1.0` that does not track the plugin version (it never tracked 0.5.0); left untouched to avoid scope creep — only plugin.json is the canonical version carrier.
- `bash scripts/manifest-lint.sh` exits 0 (9 manifests, 0 warnings) both before and after the edits.

## Issues Fixed

Applied from the star-chamber council review (gemini-3.1-pro: excellent/no issues; gpt-5.4: good, no consensus/majority issues):

1. **README intro (medium, correctness):** made the terminal nature of document mode explicit — it ends after inline edits + council review + its own commit and never enters phases 2/3.
2. **README example (low, correctness):** reworded `/brains:brains --document-mode "…"` comment from "Force document-mode delegation" to "Request document-mode delegation … (when eligible)" to match the documented asymmetric-override constraints (manual override can warn-and-confirm or hard-refuse).

## Issues Deferred (out of phase-3 scope)

- Council "atomic commit" invariant-precision notes (README/CHANGELOG): the precondition/abort-on-failed-review detail belongs in `skills/document/SKILL.md` (the implementation contract, phases 1–2), not in release-facing docs. The README/CHANGELOG wording matches ADR-006 req 27 ("commit the document changes atomically … `docs:`-prefixed").
- Stylistic suggestions (shorten the dense modes/flags section, condense the plugin-structure tree, shorten the plugin.json description, split long CHANGELOG bullets) touch pre-existing content unrelated to document mode; deferred to avoid scope creep.
