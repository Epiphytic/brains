# Storage Conventions

## Source Extension per Type

| `--type` | Source language | Extension | Fenced-block language |
|---|---|---|---|
| `flowchart` | Mermaid | `.mmd` | `mermaid` |
| `state` | Mermaid | `.mmd` | `mermaid` |
| `c4` | Structurizr DSL | `.dsl` | `dsl` |

## Canonical Naming

Diagrams are stored in `docs/adr/diagrams/`. The filename stem is derived from the ADR filename:

```
ADR filename:  docs/adr/2026-04-23-002-brains-diagramming.md
Stem:          2026-04-23-002-brains-diagramming
Mermaid:       docs/adr/diagrams/2026-04-23-002-brains-diagramming-flowchart.mmd
                 docs/adr/diagrams/2026-04-23-002-brains-diagramming-flowchart.svg
Structurizr:   docs/adr/diagrams/2026-04-23-002-brains-diagramming-c4.dsl
                 docs/adr/diagrams/2026-04-23-002-brains-diagramming-c4.svg
```

Derivation rule: strip the leading `docs/adr/` path and the trailing `.md` extension from the ADR filename. Append `-<type>` and the appropriate extension (`.mmd` for Mermaid types, `.dsl` for c4). The `.svg` extension is identical regardless of source language.

**Stem sanitization (required):** Before constructing any output path, apply `basename` to the stem (remove any directory component). Reject stems containing `..`, `/`, or `\`. The resolved output path MUST start with `docs/adr/diagrams/` — never write diagram files outside this directory.

The source file (`.mmd` or `.dsl`) is **canonical**. The `.svg` is a derived artifact and MAY be regenerated at any time from the source.

## ADR `## Diagram` Section Format

### When SVG is available

```markdown
## Diagram

![<alt text>](diagrams/<stem>-<type>.svg)

<details><summary><source-label></summary>

\`\`\`<fenced-block-language>
<source here>
\`\`\`

</details>
```

Field substitutions:

| `--type` | `<alt text>` | `<source-label>` | `<fenced-block-language>` |
|---|---|---|---|
| `flowchart` | `flowchart diagram` | `Mermaid source` | `mermaid` |
| `state` | `state machine diagram` | `Mermaid source` | `mermaid` |
| `c4` | `C4 context diagram` | `Structurizr DSL source` | `dsl` |

The `<details>` block is always present — even when SVG exists — so the ADR is fully readable in environments that don't render images.

### When no renderer is available (source-only)

```markdown
## Diagram

<!-- renderer unavailable; to enable SVG rendering, run /brains:setup --with-kroki (required for c4) or install @mermaid-js/mermaid-cli (Mermaid types only) -->

<details><summary><source-label></summary>

\`\`\`<fenced-block-language>
<source here>
\`\`\`

</details>
```

The image reference line is omitted. The HTML comment appears on the line immediately before the `<details>` block. The source file (`.mmd` or `.dsl`) is still written to `docs/adr/diagrams/`.

## Atomicity Rule

When writing or regenerating a diagram:
1. Write the source file (`.mmd` or `.dsl`) **first**.
2. Attempt to produce and write the `.svg` file **second**.
3. If the `.svg` write fails, **remove** any pre-existing `.svg` file for this stem+type so no stale `.svg` artifact remains.

Never leave a `.svg` file that does not correspond to the current source file.
