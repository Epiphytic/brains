# BRAINS Diagramming Feature Research

**Date:** 2026-04-23
**Status:** Research only — no decisions made
**Scope:** Adding diagramming to BRAINS phase 1 (brainstorm + ADR generation) with visual companion integration

---

## 1. The claude-diagrams Skill

**Repo:** https://github.com/tirandagan/claude-diagrams
**License:** MIT
**Stars:** 1
**Commits:** 2 (both March 12 2026 — initial commit and README polish)
**Maintenance:** Minimal. Two-commit initial drop with no releases and no open issues. Do not depend on it as a versioned dependency.

What it does: dispatches natural-language diagram requests to the Kroki.io cloud rendering API using only `curl`. Selects from 22+ diagram types across multiple DSLs: Mermaid (flowchart, Gantt), PlantUML (sequence, class, state, C4), Graphviz DOT, D2, ERD, DBML, NwDiag, BlockDiag, WaveDrom, Vega-Lite, etc. For each diagram it writes three files to a `diagrams/` directory: `{slug}.{ext}` (source), `{slug}.svg`/`.png` (rendered by Kroki), and `{slug}.md` (rationale doc referencing the image).

Invocation: Claude Code skill (`/diagram [description]`). `allowed-tools` limited to `Read, Grep, Glob, Bash(curl *), Bash(mkdir *), Bash(ls *)`. The skill body drives the model through an 8-step loop: analyze request → select type → design layout → write source → POST to `https://kroki.io/{type}/svg` → verify response → save files → present result.

Rendering: entirely cloud-side. Plugin requires only `curl` and internet access. Self-hosted Kroki requires Docker or a JVM-based standalone jar — neither is acceptable as a hard plugin dependency.

Privacy concern: Kroki.io (https://github.com/yuzutech/kroki, 4.1k stars, actively maintained) has no published privacy or data-retention statement. Diagram source describing internal system architecture is transmitted to a third-party server. Cannot be the default for a marketplace plugin.

**Assessment:** adopt the storage convention (source + rendered side-by-side, `diagrams/` subdirectory, `.md` rationale file) and the skill-as-loop pattern. Do not vendor or depend on it as shipped. Reimplement the rendering step with a local binary as the default and Kroki as an explicit opt-in flag (`--kroki`).

---

## 2. Diagram DSL Landscape

### Mermaid — v11.14.0

**npm package:** `mermaid@11.14.0` (April 2025); `@mermaid-js/mermaid-cli@11.12.0` (September 2025). 87.6k GitHub stars (https://github.com/mermaid-js/mermaid). Actively maintained; 5.8M npm downloads/week.

**CLI rendering.** `npx -p @mermaid-js/mermaid-cli mmdc -i foo.mmd -o foo.svg`. Requires Node ≥18.19 + Puppeteer + Chromium (~170 MB on first `npx` run). Known issues: Chromium version mismatches, ARM macOS aarch64 failures without system-Chrome workaround, Linux sandbox restrictions. Workaround exists (`--puppeteerConfigFile` pointing to system Chrome) but requires one-time user setup. SVG is default output.

**Browser rendering — zero install.** Single CDN script tag renders Mermaid source blocks as inline SVG:
```html
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true });
</script>
```
Any `<pre class="mermaid">` is converted client-side. No build step. No committed SVG.

**GitHub native.** GitHub renders Mermaid fenced code blocks in Markdown natively since 2022. ADRs with inline ` ```mermaid ``` ` blocks are readable in the GitHub UI without tooling.

**Claude output quality.** Highest of any DSL. Mermaid is the de-facto LLM-to-diagram language (Mermaid.ai, April 2026: https://mermaid.ai/blog/posts/claude-to-mermaid-ai-generated-diagrams). The BRAINS ADR template already instructs Claude to write Mermaid. Syntax quirks exist (reserved words, special characters requiring quotes) — must be called out in a diagram-conventions reference.

**Supported diagram types.** 25+: flowchart, sequence, class, state, ER, git graph, mindmap, Sankey, C4 architecture, quadrant, timeline, kanban, etc.

### D2 (terrastruct) — v0.7.1 (August 2025)

**Install.** `brew install d2` (macOS + Linux with Homebrew) or `curl -fsSL https://d2lang.com/install.sh | sh`. Single Go binary, no runtime deps. `d2 input.d2 output.svg`. SVG primary; PNG and PDF supported. 23.6k stars (https://github.com/terrastruct/d2). 34 releases.

**Rendering.** Offline, single binary. No Puppeteer, no JVM, no external API. Reliable on macOS and Linux.

**Claude output quality.** Moderate-good. Less represented in LLM training data than Mermaid; Claude produces syntactically correct D2 more often than not but makes more errors than with Mermaid. D2 produces cleaner SVGs for complex architecture diagrams (ELK, TALA layout algorithms). Not GitHub-native — D2 blocks do not render in the GitHub UI.

### Graphviz / DOT — v14.1.5

**Install.** `brew install graphviz` or `apt install graphviz`. Single C binary, every major package manager. `dot -Tsvg -o output.svg input.dot`.

**Claude output quality.** Good for dependency graphs, DAGs, call graphs. Verbose for layered architecture diagrams. No native support for groupings/containers without subgraph workarounds.

### PlantUML — ruled out

Requires JVM (Java ≥ 8). Violates the hard constraint.

### Structurizr DSL — over-engineered

SVG CLI export requires headless Chromium (Puppeteer) or Structurizr cloud. Appropriate for org-wide C4 workspaces, not per-ADR diagrams.

### Summary table

| DSL | Version | Claude quality | Local SVG | Install friction | GitHub native |
|---|---|---|---|---|---|
| Mermaid | 11.14.0 | Excellent | mmdc + Puppeteer (medium) | Medium | Yes |
| D2 | 0.7.1 | Moderate-good | Single binary | Low | No |
| Graphviz DOT | 14.1.5 | Good for graphs | Single binary | Very low | No |
| PlantUML | current | Good | JVM required | High | No |

---

## 3. SVG Rendering Pipelines

**Option A — mmdc CLI (Mermaid via npx).** First run downloads Chromium. ARM macOS and some Linux distros require manual Chromium config. Not universally reliable without one-time setup. Medium friction.

**Option B — D2 binary.** `d2 foo.d2 foo.svg`. Single Go binary installed via brew or curl. Offline, no runtime deps. Reliable on macOS + Linux. Lowest friction for a committed SVG file, but requires D2 as the DSL.

**Option C — Kroki.io cloud.** `curl -s -o foo.svg https://kroki.io/mermaid/svg --data-binary @foo.mmd`. No local install. Supports all DSLs. Sends source to a third-party server with no privacy statement. Requires internet. Acceptable as explicit opt-in; blocker as default.

**Option D — Mermaid CDN in browser.** Add CDN script tag to `frame-template.html`. Write `<pre class="mermaid">` in HTML fragments during brainstorming. Browser renders SVG live — no toolchain. The visual companion server already triggers WebSocket reload on new content (server.cjs). Zero install. Does not produce a committed SVG.

**Recommended default for ADR SVG.** Attempt D2 (B) if `d2` in PATH, then `mmdc` via npx with system-Chrome config (A) if available, then degrade gracefully: commit source only, keep inline Mermaid block in ADR (GitHub renders), annotate with renderer hint. For visual companion during brainstorming: Option D, zero-install.

---

## 4. Storage Conventions

**Inline Mermaid in ADR only (current).** `## Diagram` contains a fenced Mermaid block. GitHub renders natively. Zero friction. Downside: no standalone SVG for external embedding; source interleaved with ADR prose.

**Side-by-side source + SVG in `docs/adr/diagrams/`.** `adr-002-component-relations.mmd` + `adr-002-component-relations.svg`. ADR `## Diagram` references SVG by relative path and retains inline Mermaid as GitHub fallback. Clean separation. Pattern adopted by claude-diagrams and arc42+C4.

**Source only, generate SVG on build.** Commit source; generate SVG in CI. Structurizr/arc42 pattern — SVG treated as derived. Tension with stated requirement ("rendered by default to SVG").

**MADR.** No explicit diagram storage convention.

**Recommended for BRAINS.** When renderer available: commit both source and SVG to `docs/adr/diagrams/`; reference SVG in `## Diagram`; keep inline Mermaid block as fallback. When no renderer: commit source only; inline block renders on GitHub; annotate with renderer hint.

---

## 5. Integration Touchpoints in BRAINS

**SKILL.md phase 1.** Two points:

- Step 4 (visual companion offer): extend to "I can also show architecture diagrams as we talk through components." If accepted, use CDN path — no toolchain, live rendering as brainstorming evolves.
- Step 8 (ADR generation): when diagram condition fires (≥3 components + ≥2 relationships, or ≥1 state machine), generate source, attempt SVG render via detected binary, write to `docs/adr/diagrams/`, update `## Diagram` to reference SVG + retain inline block.

**Visual companion (server.cjs + frame-template.html).** Server already handles SVG at `/files/{filename}` with `Content-Type: image/svg+xml` (MIME_TYPES map). `frame-template.html` has no Mermaid JS. One CDN script tag in `<head>` enables live `<pre class="mermaid">` rendering in any HTML fragment. No server.cjs changes. Existing WebSocket reload handles live updates.

**ADR template (adr-template.md).** `## Diagram` with condition and Mermaid placeholder exists. Integration is additive: at ADR write time, produce source, attempt SVG render, write both to `docs/adr/diagrams/`, update section to reference SVG while retaining inline block.

**Token efficiency (v0.3 ethos).** Rendering and storage logic belongs in a new reference file (`skills/brains/references/diagram-conventions.md`), declared `lazy-on-demand` in the phase-1 manifest. Loaded only when diagram condition fires. Zero token cost for runs that don't trigger it. Visual companion path needs a brief addition to `visual-companion.md` (diagram-capable fragment guidance), not a separate reference.

---

## 6. Prior Art

**oh-my-mermaid** (https://github.com/oh-my-mermaid/oh-my-mermaid). Claude Code plugin; `/omm-scan` + `/omm-push`. Generates architecture perspectives from codebase analysis. Stores source `.mmd` in `.omm/perspectives/{name}/diagram.mmd`; no committed SVG (no SVG rendering on roadmap). Validates Claude-Code-native Mermaid workflows; not directly applicable to per-ADR.

**Swark** (https://github.com/swark-io/swark). VS Code extension; LLM-driven Mermaid from source code; renders in VS Code preview; no file storage. Not a model for BRAINS.

**arc42 + C4 + Structurizr.** Canonical docs-as-code architecture pattern: Structurizr DSL as model, derive views, generate on build (Docker + structurizr-cli). Key lesson: DSL source is canonical; SVGs are derived. Overhead (workspace model, Docker, pipeline) disproportionate for per-ADR.

**Mermaid.ai blog — "From Claude to Mermaid" (April 14 2026, https://mermaid.ai/blog/posts/claude-to-mermaid-ai-generated-diagrams).** Confirms Claude → Mermaid is mainstream at scale. Key insight: challenge is not generation but maintaining diagrams as living documents. Versioned DSL source in git is the answer.

**addjam.com — "AI Language Models for System Design and UML Diagrams" (March 2025).** Recommendation: Mermaid as LLM output DSL; human-review generated diagrams; bounded complexity per diagram.

---

## 7. Constraints That Shape the Design

Hard constraints:
1. No JVM. Rules out PlantUML and Kroki standalone jar.
2. No external cloud API as default. Kroki.io ships source to a third party with no privacy statement. Must be explicit opt-in (`--kroki`).
3. macOS + Linux without mandatory heavy install. D2 (`brew install d2`) is the cleanest local renderer. mmdc viable with system Chrome, not "just works" without detection and fallback.
4. Graceful degradation required. No renderer: commit DSL source, skip SVG, keep inline Mermaid, emit one-line renderer hint. ADR readable as text.
5. Token efficiency. Rendering logic lives in `lazy-on-demand` reference file. SKILL.md must not absorb diagram generation instructions inline.
6. Text-reviewable source for multi-LLM review. SVG alone not reviewable by star-chamber. DSL source always committed alongside SVG.
7. Mermaid already in SKILL.md. Path of least resistance keeps Mermaid as ADR DSL; add render + externalize step on top.

Tensions for the questionnaire:
- **DSL choice:** Mermaid-only vs. D2-only vs. Mermaid primary with D2 as alternative renderer?
- **Rendering pipeline:** mmdc via npx vs. D2 binary vs. browser CDN only vs. Kroki opt-in?
- **Storage:** inline Mermaid only vs. externalize source + SVG to `docs/adr/diagrams/` vs. source-only committed?
- **Visual companion integration:** Mermaid CDN in `frame-template.html` (live browser rendering) vs. pre-rendered SVG served via `/files/`?

---

## Sources

- https://github.com/tirandagan/claude-diagrams
- https://raw.githubusercontent.com/tirandagan/claude-diagrams/master/skills/diagram/SKILL.md
- https://github.com/mermaid-js/mermaid — https://github.com/mermaid-js/mermaid-cli
- https://deepwiki.com/mermaid-js/mermaid-cli
- https://mermaid.js.org/intro/
- https://github.com/terrastruct/d2
- https://graphviz.org/download/
- https://kroki.io — https://docs.kroki.io/kroki/setup/install/
- https://github.com/oh-my-mermaid/oh-my-mermaid
- https://github.com/swark-io/swark
- https://mermaid.ai/blog/posts/claude-to-mermaid-ai-generated-diagrams
- https://addjam.com/blog/2025-03-31/ai-llm-system-design-uml-diagrams/
- https://github.com/bitsmuggler/arc42-c4-software-architecture-documentation-example
