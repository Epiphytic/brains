# Renderer Conventions

## Detection Sequence

Check renderers in this exact priority order. Stop at the first that succeeds.

### 1. Local Kroki container (preferred)

Check for `~/.config/brains/renderer.json`. If the file exists and contains a `kroki_url` field:

```
POST ${kroki_url}/mermaid/svg
Content-Type: text/plain
Body: <mermaid source>
```

A 200 response with SVG content means the renderer is available. Use this renderer.

If the file is absent, `kroki_url` is missing, or the POST fails (connection refused, non-200): fall through to the next renderer.

### 2. mmdc via npx (secondary)

Attempt:

```bash
npx -p @mermaid-js/mermaid-cli mmdc -i <input.mmd> -o <output.svg>
```

If npx is not installed, the package download fails, or mmdc exits non-zero: fall through.

### 3. Source-only fallback

No SVG is produced. Write the `.mmd` file only. Emit the HTML comment hint in the ADR `## Diagram` section:

```html
<!-- renderer unavailable; to enable SVG rendering, run /brains:setup --with-kroki or install @mermaid-js/mermaid-cli -->
```

## NO-CLOUD DEFAULT

**The skill MUST NOT send diagram source to any external cloud service by default.**

Kroki.io (`https://kroki.io`) is an external cloud service. It MUST NOT be used as an automatic fallback. The local Kroki container (`yuzutech/kroki` running on the user's machine) is distinct from the public Kroki.io cloud — using the local container does not violate this rule.

## --kroki-cloud Explicit Consent Path

The user MAY pass `--kroki-cloud` to opt into the public `https://kroki.io` cloud renderer. Requirements:
- Requires explicit re-confirmation each invocation: prompt the user with "This will send your diagram source to https://kroki.io (an external cloud service). Confirm? [y/N]"
- If the user does not confirm, fall back to source-only.
- MUST NOT be used as an automatic fallback under any circumstances.

## renderer.json Immutability Rule

`~/.config/brains/renderer.json` is written **only** by `brains:setup --with-kroki` and deleted/cleared **only** by `brains:setup --without-kroki`. No other BRAINS skill reads or modifies this file except to read `kroki_url` for renderer detection. This file MUST NOT be created, modified, or deleted by `brains:diagram` or any other non-setup skill.
