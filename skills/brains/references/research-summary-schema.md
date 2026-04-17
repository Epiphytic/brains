# Research-Summary Block Schema (--lean)

Under `--lean`, `/brains:brains` writes a compact structured summary of the research document into the plan header at `docs/plans/YYYY-MM-DD-<slug>-map.md`. Downstream consumers (phase-2 planning subagent, phase-3 teammate grooming, phase-3 implementation subagents) read this summary instead of the full research document. The full research document remains on disk for drill-down when a summary field is empty-but-relevant.

## Required fields

The summary block MUST be fenced and tagged, placed inside the plan header. All five fields MUST be present. Fields MAY be empty (an empty field signals "no findings in this category"), but missing fields MUST fail `manifest-lint`.

```yaml
research-summary:
  libraries-and-versions: |
    <bullet list of libraries used, with current-stable version, in the library's native versioning scheme>
  deprecated-apis-to-avoid: |
    <bullet list of APIs/patterns that were deprecated in the versions referenced above>
  codebase-patterns: |
    <bullet list of idiomatic patterns found in this repo or the ecosystem, cited by file path when applicable>
  prior-art: |
    <bullet list of blog posts, reference implementations, or prior ADRs/plans that informed the decision>
  constraints: |
    <bullet list of non-negotiable constraints from the research: compliance, compatibility floors, runtime limits, etc.>
```

## Size budget

Target total size: 20 lines, 400 tokens or less. When a field requires more detail, write a one-line pointer to the section in the full research document (e.g. `see §3 of the research document`) rather than inlining the content.

## Drill-down rules

A downstream consumer MUST drill down into the full research document when:
- A task's topic intersects a summary field that is empty but the research document has a matching section — the summary's emptiness was a summarization error, not an absence.
- A task is flagged `risk:high` during grooming and any summary field is ambiguous.
- `--ignore-research-summary` is passed (opt-out for the run).

Drill-down means reading `docs/plans/YYYY-MM-DD-<slug>-research.md` in full.

## Writer responsibility

The writing agent (phase-1 synthesis subagent under `--lean`) MUST:
- Populate every field.
- Not summarize away specific version numbers, compliance references, or deprecated-API names — these are the fidelity-critical tokens.
- Mark a field with a single line of form `<see research §N>` when content exceeds the size budget.

## Example

```yaml
research-summary:
  libraries-and-versions: |
    - FastAPI 0.112 (web framework)
    - SQLAlchemy 2.0 (ORM)
    - Alembic 1.13 (migrations)
  deprecated-apis-to-avoid: |
    - SQLAlchemy 1.x Query API (declarative_base in 2.0 is deprecated; use DeclarativeBase)
    - Pydantic v1 BaseSettings (moved to pydantic-settings in v2)
  codebase-patterns: |
    - Repository pattern in src/repos/ (see base_repo.py)
    - Settings injection via Pydantic BaseSettings in src/config.py
  prior-art: |
    - ADR-003 (auth middleware refactor) — background on session-token constraint
    - https://fastapi.tiangolo.com/advanced/async-sql/ — async SQLAlchemy idioms
  constraints: |
    - MUST maintain Python 3.11 compatibility (platform constraint)
    - MUST preserve API response schema from v2 (external consumer contract)
```
