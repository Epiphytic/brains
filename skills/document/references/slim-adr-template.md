# Slim ADR Template (Document Mode)

Use this template when `/brains:document` produces a slim ADR in `docs/adr/`. Filename format: `YYYY-MM-DD-NNN-<title>.md` where NNN is a globally sequential number (check `docs/adr/` for the next available number).

This is the **slim** variant of `$BRAINS_PATH/skills/brains/references/adr-template.md`: it retains only Context, Decision, Requirements (RFC 2119), and Consequences, and OMITS Assumed Versions and Diagram by design. Use RFC 2119 MUST / MUST NOT / SHOULD / SHOULD NOT / MAY language in the Requirements section.

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

## Consequences
<What changes as a result>
```
