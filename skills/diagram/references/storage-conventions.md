# Storage Conventions

## Canonical Naming

Diagrams are stored in `docs/adr/diagrams/`. The filename stem is derived from the ADR filename:

```
ADR filename: docs/adr/2026-04-23-002-brains-diagramming.md
Stem:         2026-04-23-002-brains-diagramming
.mmd output:  docs/adr/diagrams/2026-04-23-002-brains-diagramming-flowchart.mmd
.svg output:  docs/adr/diagrams/2026-04-23-002-brains-diagramming-flowchart.svg
```

Derivation rule: strip the leading `docs/adr/` path and the trailing `.md` extension from the ADR filename. Append `-<type>` and the appropriate extension.

The `.mmd` source file is **canonical**. The `.svg` is a derived artifact and MAY be regenerated at any time from the `.mmd`.

## ADR `## Diagram` Section Format

### When SVG is available

```markdown
## Diagram

![<type> diagram](diagrams/<stem>-<type>.svg)

<details><summary>Mermaid source</summary>

\`\`\`mermaid
<mermaid source here>
\`\`\`

</details>
```

The `<alt>` text for the image should be descriptive: e.g., `flowchart diagram`, `state machine diagram`, `C4 context diagram`.

The `<details>` block is always present — even when SVG exists — so the ADR is fully readable in environments that don't render images.

### When no renderer is available (source-only)

```markdown
## Diagram

<!-- renderer unavailable; to enable SVG rendering, run /brains:setup --with-kroki or install @mermaid-js/mermaid-cli -->

<details><summary>Mermaid source</summary>

\`\`\`mermaid
<mermaid source here>
\`\`\`

</details>
```

The image reference line is omitted. The HTML comment appears on the line immediately before the `<details>` block. The `.mmd` file is still written to `docs/adr/diagrams/`.

## Atomicity Rule

When writing or regenerating a diagram:
1. Write the `.mmd` source file **first**.
2. Attempt to produce and write the `.svg` file **second**.
3. If the `.svg` write fails, **remove** any pre-existing `.svg` file for this stem+type so no stale `.svg` artifact remains.

Never leave a `.svg` file that does not correspond to the current `.mmd` source.
