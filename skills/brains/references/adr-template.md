# ADR Template

Use this template when producing ADRs in `docs/adr/`. Filename format: `YYYY-MM-DD-NNN-<title>.md` where NNN is a globally sequential number (check `docs/adr/` for the next available number).

Use RFC 2119 MUST / MUST NOT / SHOULD / SHOULD NOT / MAY language in the Requirements section. Include a mermaid diagram if the ADR has three or more components with two or more relationships, or at least one state machine.

```markdown
# ADR-NNN: <Title>

**Date:** YYYY-MM-DD
**Status:** Accepted
**Decision makers:** <user + providers consulted>

## Context
<Why this decision is needed>

## Decision
<Prose summary of what was decided — the high-level choice and its shape>

## Requirements (RFC 2119)
<Testable MUST/SHOULD/MAY statements derived from the decision>
- The system MUST <requirement>.
- The system SHOULD <requirement>.
- The system MAY <requirement>.

## Rationale
<Why this option over alternatives>

## Alternatives Considered
### <Alternative 1>
- Pros: ...
- Cons: ...
- Why rejected: ...

## Assumed Versions (SHOULD)
- <framework/lib>: X.Y — in whatever versioning scheme the library uses
- <api>: X.Y

## Diagram
<mermaid block, if warranted: ≥3 components with ≥2 relationships, or ≥1 state machine>

## Consequences
<What changes as a result>

## Council Input
<Summary of star-chamber feedback, when applicable>
```
