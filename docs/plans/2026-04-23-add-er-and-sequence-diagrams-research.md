# Research: Add `er` and `sequence` Diagram Types to `brains:diagram`

**Date:** 2026-04-23
**Status:** Research complete — feeds question generation and ADR synthesis
**Scope:** v0.5 promotion of `er` and `sequence` from reserved slots (per ADR-002) to active types

---

## 1. Mermaid `erDiagram` — Current Stable Syntax and Pitfalls

### Minimal Valid Syntax

```
erDiagram
    CUSTOMER {
        int id PK
        string name
        string email UK
    }
    ORDER {
        int id PK
        int customer_id FK
        string status
    }
    CUSTOMER ||--o{ ORDER : "places"
```

Entity attributes use `type name [PK|FK|UK] ["comment"]` per line. Attribute block is optional — a bare entity name is valid. Multiple key markers comma-separated: `int id PK, FK`. Optional direction: `erDiagram LR` (default TB).

### Cardinality Notation (Crow's Foot)

| Symbol | Meaning |
|---|---|
| `\|\|--\|\|` | One to one |
| `\|\|--o{` | One to zero-or-more |
| `\|\|--\|{` | One to one-or-more |
| `\|o--o{` | Zero-or-one to zero-or-more |
| `}o--o{` | Zero-or-more to zero-or-more |

Identifying line: `--` (solid). Non-identifying: `..` (dashed).

### Known Pitfalls for LLM Generation

**Pitfall 1 — Parameterized types break the parser.** `varchar(255)`, `decimal(10,2)` contain commas/parens, not permitted. Use `varchar255`, `string`, `decimal`.

**Pitfall 2 — `to` (and similar verbs) as unquoted relationship labels.** `to` tokenizes as IDENTIFYING keyword. Always quote labels: `CUSTOMER ||--o{ ORDER : "places"`.

**Pitfall 3 — Alias notation with spaces before `--`/`..` in Mermaid ≥ 11.13 (issue #7482).** `A 1 -- 1+ B : label` fails. Remove spaces: `A 1--1+ B : label`. Standard crow's-foot notation (no aliases) is unaffected and preferred.

**Pitfall 4 — Attribute names starting with a digit.** `int 2fa_enabled` fails. Use `bool twofa_enabled`.

**Pitfall 5 — Cardinality circle rendering in wide diagrams** (issues #4342, #8153). The `o` circle floats off edges with >10 entities. Cap auto-generated ER diagrams at ≤10 entities.

### Kroki vs. mmdc Behavior

Both paths use the same Mermaid.js library via Puppeteer + headless Chromium. No erDiagram-specific divergence. Both are valid for `er`.

**SHOULD-level version pin:** Mermaid 11.13+. The existing `mermaid@11` CDN tag in `frame-template.html` satisfies this.

---

## 2. Mermaid `sequenceDiagram` — Current Stable Syntax and Pitfalls

### Minimal Valid Syntax

```
sequenceDiagram
    participant C as Client
    participant S as Server
    participant DB as Database

    C->>+S: POST /login
    S->>DB: SELECT user
    DB-->>S: row
    S-->>-C: 200 OK
```

### `participant` vs. `actor`

- `participant` (rectangle): systems, services, processes
- `actor` (stick figure): humans

Other shapes (`boundary`, `control`, `entity`, `database`, `collections`, `queue`) render poorly in some themes — limit generated output to `participant` and `actor`.

Always declare all participants at the top. Mermaid infers order-of-first-mention for undeclared names, which produces unpredictable left-to-right ordering.

### Arrow Types

| Syntax | Semantics |
|---|---|
| `A->>B: msg` | synchronous call / request |
| `A-->>B: msg` | synchronous return / response |
| `A-xB: msg` | fire-and-forget / discard |
| `A-)B: msg` | async message |
| `A--)B: msg` | async callback / return |
| `A<<->>B: msg` | bidirectional (v11.0+) |

Convention for generated diagrams: `->>` for calls, `-->>` for responses.

### Activation / Deactivation

```
%% Inline shorthand (preferred — pairs arrow and activation on one line):
C->>+S: request
S-->>-C: response

%% Explicit (use for stacked activations):
activate S
S->>DB: query
DB-->>S: result
deactivate S
```

The inline `+/-` form physically couples activation to its arrow, which reduces mismatched-pair errors — MermaidSeqBench identifies activation mismatches as a top-3 LLM failure mode.

### Control-Flow Blocks (all close with `end`)

`loop ... end` | `alt ... else ... end` | `opt ... end` | `par ... and ... end` | `critical ... option ... end` | `break ... end`

### Notes

```
Note right of S: text
Note left of C: text
Note over C,S: text spanning two
```

Supports `<br/>` for line breaks.

### Common LLM Generation Pitfalls

**Pitfall 1 — Implicit participant ordering.** Declare all `participant` lines before any message line.

**Pitfall 2 — Mismatched activate/deactivate.** Use inline `+/-` shorthand by default.

**Pitfall 3 — `end` inside unquoted message labels.** `S->>C: session end` silently closes the current block. Quote: `S->>C: "session end"`.

**Pitfall 4 — Arrow-direction reversal.** Left side sends. State sender→receiver convention explicitly in generation context.

**Pitfall 5 — Colon in unquoted labels.** `:` separates arrow from label. `C->>S: POST /api: body` truncates to `POST /api`. Quote: `C->>S: "POST /api: body"`.

### Kroki vs. mmdc Behavior

Same Mermaid.js library; no divergence. Sequence diagrams produce SVGs without fixed pixel dimensions (unlike Structurizr); consistent across both paths.

**SHOULD-level version pin:** Mermaid 11.13+. The `mermaid@11` CDN tag satisfies this.

---

## 3. Sequence Auto-Trigger Heuristic — Prior Art and Proposals

### Prior Art

- **arc42 (tip 6-11):** Sequence diagrams are for *runtime scenarios* — what happens during execution, not what exists. The implicit discriminator vs. flowchart: flowcharts describe process/decision flow; sequence diagrams describe message-passing protocols between identified actors. No formal detection threshold published.
- **C4 model:** Treats sequence/collaboration diagrams as dynamic views. Trigger is a named runtime scenario with an identified initiator, goal, and ordered message steps between named containers or components.
- **GenAI tooling (2025):** No published auto-dispatch heuristics in arc42 toolchains, docToolchain, or structurizr-cli. Selection universally left to authors.

### Candidate Heuristics

**Candidate A — Message-exchange count (recommended)**

> `sequence` — architecture describes ≥2 named participants AND ≥3 ordered message exchanges (request/response, call/return, publish/subscribe, or sequential event steps) between them.

- Pros: concrete, low false-positive rate, maps to arc42 runtime-scenario framing. Fewer than 3 exchanges are adequately shown on a labelled flowchart edge. Parallels the ER heuristic's count-based structure.
- Cons: prose must name both sender and receiver; vague "the client sends a request" may not qualify.

**Candidate B — Protocol vocabulary signal**

Trigger on explicit protocol vocabulary: HTTP request/response pairs, webhook/callback, pub/sub event names, authentication handshake steps, retry loops with named actors.

- Pros: high-confidence when protocol language is present.
- Cons: higher pattern-matching complexity; overlaps with flowchart retry loops.

**Candidate C — Named-participant directionality**

Trigger on ≥3 named participants with bidirectional flow (at least one actor both sends and receives from different actors) AND ≥2 return/response steps.

- Pros: catches multi-hop interactions (A→B→C→B→A).
- Cons: highest implementation complexity.

**Recommendation:** Candidate A. It matches the existing count-based heuristic pattern (`state` and `er` are both count-based), produces a concrete threshold, and respects the `state > ER > flowchart > C4 > sequence` priority chain already in ADR-002.

---

## 4. Version / Release Labeling

### Current Version

Repository is at **v0.4.4**, confirmed by:
- ADR-002 header ("Regenerated in v0.4.4")
- Recent commit `docs(adr): regenerate ADR-002 diagrams under v0.4.4 conventions`
- README skills table listing `diagram` types as `flowchart`/`state`/`c4` only

No `package.json`, `plugin.json`, or `CHANGELOG.md` at repo root. Versioning tracked in ADR headers and conventional-commit messages.

### Landing as v0.5.0 vs. v0.4.x

ADR-002 explicitly scoped ER+sequence to "v0.5" (Decision, Requirements §Skill structure line 39, Consequences). Additions are backward-compatible: two new reference files, extended routing tables, no changes to existing types or the renderer pipeline.

**Recommendation:** **v0.5.0.** A v0.4.5 point release would technically work but breaks the explicitly published ADR milestone label. Add a revision note to ADR-002 recording the promotion (do not rewrite retroactively).

---

## 5. Codebase Touch Points

### Definite edits

| File | What needs updating |
|---|---|
| `skills/diagram/SKILL.md` | `--type` value list; routing table (2 new rows); priority-order note (remove "Reserved future slots (v0.5, inactive)"); argument-hint; option-5 regeneration enumeration |
| `skills/diagram/references/er.md` | **New file** |
| `skills/diagram/references/sequence.md` | **New file** |
| `skills/diagram/references/renderer-conventions.md` | POST path table (+2 rows, both `/mermaid/svg`); mmdc-applicability note (add `er` and `sequence`) |
| `skills/diagram/references/storage-conventions.md` | Source extension table (+2 rows); ADR `## Diagram` field-substitutions table |
| `skills/brains/SKILL.md` | Step 8 heuristics note (remove "ER and sequence are v0.5-only types"); step 9 option-5 regeneration enumeration (add `er`, `sequence`); step 1 `--diagram` valid-type list; add concrete sequence heuristic threshold |
| `docs/diagrams.md` | Replace "Reserved for v0.5" (lines 202–207) with active examples |
| `README.md` | Skills table row for `diagram`: update type list |
| `docs/adr/2026-04-23-002-brains-diagramming.md` | Add revision note documenting v0.5 promotion (do not rewrite) |

### Literal strings to replace (grep-confirmed)

- `"v0.5-only types"` — `skills/brains/SKILL.md` line 110
- `"Reserved future slots (v0.5, inactive)"` — `skills/diagram/SKILL.md` line 65
- `"Reserved for v0.5"` — `docs/diagrams.md` line 202

### No change required

- `skills/brains/scripts/frame-template.html` — the single `mermaid@11` ESM CDN import bundles all diagram parsers. No additional import or configuration needed.
- `skills/diagram/references/structurizr.md`, `flowchart.md`, `state.md` — unaffected.

---

## Sources

- [Mermaid erDiagram syntax](https://mermaid.js.org/syntax/entityRelationshipDiagram.html)
- [Mermaid sequenceDiagram syntax](https://mermaid.js.org/syntax/sequenceDiagram.html)
- [MermaidSeqBench (Nov 2025, arXiv:2511.14967)](https://arxiv.org/abs/2511.14967)
- [Mermaid issue #7482 — erDiagram alias parse regression in 11.13](https://github.com/mermaid-js/mermaid/issues/7482)
- [Mermaid issue #6625 — `to` reserved keyword in relationship labels](https://github.com/mermaid-js/mermaid/issues/6625)
- [arc42 tip 6-11 — sequence diagrams for runtime scenarios](https://docs.arc42.org/tips/6-11/)
- [Kroki documentation](https://kroki.io/)
