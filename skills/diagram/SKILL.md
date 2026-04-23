---
name: diagram
description: Generate Mermaid diagrams for ADRs and architecture documentation. Stores .mmd source and .svg output side-by-side in docs/adr/diagrams/. Invokable standalone or auto-triggered from brains:brains phase-1 step 8.
argument-hint: '"<description>" [--type <type>] [--max-diagrams N] [--no-diagram] [--diagram <type>] [--kroki-cloud]'
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

## Invocation

```
/brains:diagram "<description>" [--type <type>]
```

`--type` values: `flowchart`, `state`, `c4`  
If `--type` is omitted, infer the best type from the description using these signals:
- Mentions states, transitions, lifecycle, phases → `state`
- Mentions entities, relationships, data model → `flowchart` (ER is v0.5)
- Mentions system context, containers, external actors → `c4`
- Default: `flowchart`

## Routing Table (lazy-on-demand references)

| `--type` | Reference file | Load condition |
|---|---|---|
| `flowchart` | `skills/diagram/references/flowchart.md` | lazy-on-demand: diagram of this type is being generated |
| `state` | `skills/diagram/references/state.md` | lazy-on-demand: diagram of this type is being generated |
| `c4` | `skills/diagram/references/c4.md` | lazy-on-demand: diagram of this type is being generated |

Load the reference file for the selected type before generating Mermaid source. Do NOT load references for types not being generated.

Also load on every diagram generation:
- `skills/diagram/references/renderer-conventions.md` — lazy-on-demand: any diagram is being generated
- `skills/diagram/references/storage-conventions.md` — lazy-on-demand: any diagram is being generated

## Generation Steps

1. Load the per-type reference file and storage/renderer conventions.
2. Generate Mermaid source for the requested diagram.
3. Determine the output paths from storage-conventions.md (requires the ADR filename stem when called from ADR context).
4. Detect the renderer per renderer-conventions.md and produce SVG if possible.
5. Write `.mmd` source file first, then `.svg` (if renderer succeeded).
6. Write or update the ADR `## Diagram` section per the format in storage-conventions.md.

## Flags

| Flag | Behavior |
|---|---|
| `--type <type>` | Force the diagram type; skip heuristic inference |
| `--max-diagrams N` | Allow up to N diagrams (1-5, default 1); each from a distinct heuristic |
| `--no-diagram` | Suppress all auto-trigger; no diagram generated |
| `--diagram <type>` | Force a specific type; overrides `--max-diagrams` |
| `--kroki-cloud` | Opt-in to public kroki.io cloud renderer; requires explicit consent each invocation |

`--max-diagrams` priority order when N > 1: `state > ER > flowchart > C4 > sequence`  
(ER and sequence are v0.5 types — documented here to avoid rework; not active in v0.4)

## Self-Correction and Regeneration

**Retry loop:** On renderer syntax error, append the error to generation context and retry once (exactly one retry). On second failure, write the placeholder below.

**Placeholder (second failure):**
```
flowchart TD
  A["Diagram placeholder — manual revision required\nSee: docs/adr/diagrams/<stem>-<type>.mmd"]
```
Omit SVG for placeholders. Add to ADR: `<!-- diagram generation failed after one retry; edit docs/adr/diagrams/<stem>-<type>.mmd manually -->`

**Atomic overwrite:** Write `.mmd` first, `.svg` second. If `.svg` write fails, remove any pre-existing `.svg` for this stem+type — never leave a stale `.svg`.

**Option-5 regeneration:** After a revised ADR is written, enumerate `docs/adr/diagrams/` for anchored per-type matches (`<adr-stem>-state.mmd`, `<adr-stem>-flowchart.mmd`, `<adr-stem>-c4.mmd`, `<adr-stem>-er.mmd`) — no wildcard globs. Re-invoke diagram generation for each match. Skip files with no auto-trigger record (manually authored); log a one-line note.
